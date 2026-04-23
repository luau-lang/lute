#include "lute/processhandle.h"

#include "lute/common.h"
#include "lute/uvutils.h"

#include "lua.h"
#include "lualib.h"

#include <cstdio>

#ifdef _WIN32
#define crossPlatformFileno(stream) _fileno(stream)
#else
#define crossPlatformFileno(stream) fileno(stream)
#endif

namespace process
{

const std::string kStdioKindDefault = "default";
const std::string kStdioKindInherit = "inherit";
const std::string kStdioKindNone = "none";

void convertCRLFtoLF(std::string& str)
{
    size_t writePos = 0;
    for (size_t readPos = 0; readPos < str.size(); ++readPos)
    {
        if (str[readPos] == '\r' && readPos + 1 < str.size() && str[readPos + 1] == '\n')
            continue; // Skip the '\r' in CRLF
        str[writePos++] = str[readPos];
    }
    str.resize(writePos);
}

ProcessExecutionState::ProcessExecutionState(int maxCompletions)
    : completed(false)
    , processCanComplete(maxCompletions)
    , exitCode(-1)
    , termSignal(0)
{
}

void ProcessExecutionState::signalProcessCompletion(int64_t exitCode, int termSignal)
{
    this->exitCode = exitCode;
    this->termSignal = termSignal;
    processCanComplete--;
}

void ProcessExecutionState::signalPipeClose()
{
    processCanComplete--;
}

int64_t ProcessExecutionState::getExitCode() const
{
    return exitCode;
}

int ProcessExecutionState::getTermSignal() const
{
    return termSignal;
}

bool ProcessExecutionState::isReadyToComplete() const
{
    return processCanComplete == 0;
}

void ProcessExecutionState::signalProcessError(std::string err)
{
    errors.emplace_back(err);
}

bool ProcessExecutionState::hasErrors() const
{
    return !errors.empty();
}

std::vector<std::string>& ProcessExecutionState::getErrors()
{
    return errors;
}

ProcessHandle::ProcessHandle(lua_State* L, ProcessOptions& opts, std::vector<std::string>& args, std::string context)
    : loop(getRuntimeLoop(L))
    , resumeToken(getResumeToken(L))
    , state(opts.stdioKind == kStdioKindDefault ? ProcessExecutionState::kWaitOnNForProcessCompletion : 1)
    , stdioKind(opts.stdioKind)
    , options({})
{
    // When the process finishes, what do we do?
    options.exit_cb = ProcessHandle::onProcessExit;
    // Program to execute
    options.file = args[0].c_str();

    // Set up all the arguments to the process (args[0] must be passed)
    for (const auto& arg : args)
    {
        processArguments.push_back(const_cast<char*>(arg.c_str()));
    }
    processArguments.push_back(nullptr);
    options.args = processArguments.data();

    // Pass a current working directory, if it exists
    // Note - in a separate pass, make these optional
    if (!opts.cwd.empty())
    {
        options.cwd = opts.cwd.c_str();
    }

    // Set up the processes environment variables
    if (!opts.env.empty())
    {
        if (auto err = uvutils::getEnvironmentVariables(opts.env))
        {
            luaL_error(L, "Failed to get current environment: %s", uv_strerror(*err));
        }
        for (const auto& [key, value] : opts.env)
            environmentStrings.push_back(key + "=" + value);
        for (auto& str : environmentStrings)
            environmentVarString.push_back(str.data());
        environmentVarString.push_back(nullptr);
        options.env = environmentVarString.data();
    }

    // Setup input output for the process
    options.stdio_count = 3;

    if (opts.stdioKind == kStdioKindNone)
    {
        stdio[0].flags = UV_IGNORE;
        stdio[1].flags = UV_IGNORE;
        stdio[2].flags = UV_IGNORE;
    }
    else if (opts.stdioKind == kStdioKindInherit)
    {
        stdio[0].flags = UV_INHERIT_FD;
        stdio[0].data.fd = crossPlatformFileno(stdin);
        stdio[1].flags = UV_INHERIT_FD;
        stdio[1].data.fd = crossPlatformFileno(stdout);
        stdio[2].flags = UV_INHERIT_FD;
        stdio[2].data.fd = crossPlatformFileno(stderr);
    }
    else if (opts.stdioKind == kStdioKindDefault)
    {
        stdinPipe = std::make_unique<uvutils::PipeStream>(loop, false, context + " stdin pipe");
        stdoutPipe = std::make_unique<uvutils::PipeStream>(loop, false, context + " stdout pipe");
        stderrPipe = std::make_unique<uvutils::PipeStream>(loop, false, context + " stderr pipe");

        stdio[0].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_READABLE_PIPE);
        stdio[0].data.stream = stdinPipe->getStream();
        stdio[1].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
        stdio[1].data.stream = stdoutPipe->getStream();
        stdio[2].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_WRITABLE_PIPE);
        stdio[2].data.stream = stderrPipe->getStream();
    }

    options.stdio = stdio;

    process.data = this;
}

void ProcessHandle::spawn(lua_State* L)
{
    int spawnResult = uv_spawn(loop, &process, &options);
    if (spawnResult != 0)
    {
        resumeToken->runtime->releasePendingToken();
        state.completed = true; // Allow close callbacks to release self
        closeHandles();
        luaL_error(L, "Failed to spawn process: %s", uv_strerror(spawnResult));
    }

    if (stdioKind == kStdioKindDefault)
    {
        // Close our write end of stdin so the child sees EOF instead of
        // blocking forever on a read.
        closePipe(stdinPipe);

        // If we have created a pipe, then this process must be responsible for closing this pipe
        // If we haven't, then these pipes should be considered closed?
        stdoutPipe->read(
            [this](std::string_view input)
            {
                state.stdoutData.append(input);
            },
            [this](std::optional<std::string> err)
            {
                state.signalPipeClose();
                tryComplete(err);
            }
        );

        stderrPipe->read(
            [this](std::string_view input)
            {
                state.stderrData.append(input);
            },
            [this](std::optional<std::string> err)
            {
                state.signalPipeClose();
                tryComplete(err);
            }
        );
    }
}

void ProcessHandle::onHandleClose()
{
    --pendingCloses;
    if (pendingCloses == 0 && state.completed)
        self.reset();
}

void ProcessHandle::closePipe(std::unique_ptr<uvutils::PipeStream>& pipe)
{
    if (!pipe)
        return;
    if (pipe->close(
            [this]()
            {
                onHandleClose();
            }
        ))
        pendingCloses++;
}

void ProcessHandle::closeHandles()
{
    closePipe(stdinPipe);
    closePipe(stdoutPipe);
    closePipe(stderrPipe);

    if (!uv_is_closing((uv_handle_t*)&process))
    {
        pendingCloses++;
        uv_close(
            (uv_handle_t*)&process,
            [](uv_handle_t* handle)
            {
                auto ph = static_cast<ProcessHandle*>(handle->data);
                ph->onHandleClose();
            }
        );
    }

    if (pendingCloses == 0 && state.completed)
        self.reset();
}

void ProcessHandle::onProcessExit(uv_process_t* process, int64_t exitStatus, int termSignal)
{
    ProcessHandle* handle = static_cast<ProcessHandle*>(process->data);
    if (!handle || handle->state.completed)
        return;

    handle->state.signalProcessCompletion(exitStatus, termSignal);
    handle->tryComplete();
}

void ProcessHandle::tryComplete(std::optional<std::string> errorMessage)
{
    if (errorMessage)
    {
        state.signalProcessError(*errorMessage);
    }
    if (state.completed)
        return;

    if (!state.isReadyToComplete())
        return;

    completeProcessExecution();
}

void ProcessHandle::completeProcessExecution()
{
    state.completed = true;

    if (!state.hasErrors())
    {
        int64_t finalExitCode = state.getExitCode();
        int finalTermSignal = state.getTermSignal();
        // TODO: should we put any leftover stdin data into the output here?
        std::string finalStdout = state.stdoutData;
        std::string finalStderr = state.stderrData;
        std::string finalSignalStr = finalTermSignal ? std::to_string(finalTermSignal) : "";
        convertCRLFtoLF(finalStdout);
        convertCRLFtoLF(finalStderr);
        resumeToken->complete(
            [=](lua_State* L)
            {
                lua_createtable(L, 0, 5); // ok, exitCode, stdout, stderr, signal

                bool ok = (finalExitCode == 0 && finalTermSignal == 0);

                lua_pushboolean(L, ok);
                lua_setfield(L, -2, "ok");

                lua_pushinteger(L, finalExitCode);
                lua_setfield(L, -2, "exitcode");

                lua_pushlstring(L, finalStdout.c_str(), finalStdout.length());
                lua_setfield(L, -2, "stdout");

                lua_pushlstring(L, finalStderr.c_str(), finalStderr.length());
                lua_setfield(L, -2, "stderr");

                if (!finalSignalStr.empty())
                {
                    lua_pushlstring(L, finalSignalStr.c_str(), finalSignalStr.size());
                }
                else
                {
                    lua_pushnil(L);
                }
                lua_setfield(L, -2, "signal");

                return 1;
            }
        );
    }
    else
    {
        std::string msg = "Process failed because: \n";
        for (const auto& err : state.getErrors())
        {
            msg += err + "\n";
        }
        resumeToken->fail(msg);
    }

    resumeToken.reset();
    closeHandles();
}

} // namespace process
