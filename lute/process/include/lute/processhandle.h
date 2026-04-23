#pragma once

#include "lute/runtime.h"
#include "lute/UVStream.h"

#include "lua.h"

#include "uv.h"

#include <atomic>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace process
{

extern const std::string kStdioKindDefault;
extern const std::string kStdioKindInherit;
extern const std::string kStdioKindNone;

struct ProcessOptions
{
    std::string cwd;
    std::string stdioKind = kStdioKindDefault;
    std::map<std::string, std::string> env;
    std::string customShell; // only used by system()
};

void convertCRLFtoLF(std::string& str);

struct ProcessExecutionState
{

    // Your process is ready to finish:
    // a) stdout stream has signalled error or EOF
    // b) ditto for stderr stream
    // c) Process has finished
    static constexpr int kWaitOnNForProcessCompletion = 3;
    ProcessExecutionState(int maxCompletions = kWaitOnNForProcessCompletion);

    void signalProcessCompletion(int64_t exitCode, int termSignal);
    void signalPipeClose();

    int64_t getExitCode() const;
    int getTermSignal() const;
    bool isReadyToComplete() const;

    void signalProcessError(std::string err);
    bool hasErrors() const;
    std::vector<std::string>& getErrors();

    std::string stdoutData;
    std::string stderrData;
    bool completed;

private:
    // Requires onStreamEnd for stderr/stdout/processExit
    std::atomic<int> processCanComplete;
    int64_t exitCode;
    int termSignal;
    std::vector<std::string> errors;
};

/**
The process handle is a tricky class that coordinates a processes' life cycle.
This does not get exposed as a user data. Instead the current thread yields
while the process runs and on completion the current coroutine resumes. This
comment will try to document how process spawning and completion currently
works.

While running, a state of a running process is tracked by the struct
ProcessExecutionState. This tracks a variable called `processCanComplete`. A
process is allowed to 'complete' when a) the stdout and stderr stream signals
EOF, and b) the processExit callback gets called. Each of the callbacks
decrements `processCanComplete` and then calls `tryComplete`.

tryComplete now attempts to schedule close callbacks for each of the pipes we
opened - input, output, error pipes. We increment a pending closes variable and
decrement it when the close finishes execution. The process handle stores a self
reference so that it stays alive long enough across all the various libuv
callbacks. We need to ensure this self reference is freed when appropriate.

Some callouts:

- Stdiokind makes this tricky! If you spin up a process in the default mode, we
  actively create a pipe and initialize it with certain settings. However, child
  processes inherit the file descriptors of the parent. This means you have to
  be very careful here about calling onRead on the uvutils::PipeStream. A child
  process that is Inherit or None will never receive any data as the pipe object
  doesn't get connected to the file descriptor (only the parent gets this).
  However, the actual pipe object sending EOF is a pre-requisite to closing the
  process

- We need to close stdin/stdout/stderr in order for the process to close
  successfully. If you spawn a process in default mode, and then it spawns a
  process in inherit mode, there is no api to send data to the child process (we
  don't have process interception). The child process will wait for input
  indefinitely (which will never come). For that reason, we can pre-emptively
  close the pipe in the parent process after spawning, which lets the child see
  EOF and avoid hanging indefinitely. When we have an actual process.spawn that
  lets you intercept file descriptors, we can revisit this.
 */
struct ProcessHandle
{
    uv_process_t process;
    uv_loop_t* loop = nullptr;

    ResumeToken resumeToken;
    std::shared_ptr<ProcessHandle> self;
    std::atomic<int> pendingCloses{0};

    std::unique_ptr<uvutils::PipeStream> stdinPipe;
    std::unique_ptr<uvutils::PipeStream> stdoutPipe;
    std::unique_ptr<uvutils::PipeStream> stderrPipe;
    ProcessExecutionState state;
    std::string stdioKind;

    uv_process_options_t options;
    uv_stdio_container_t stdio[3];
    std::vector<char*> processArguments;
    std::vector<std::string> environmentStrings;
    std::vector<char*> environmentVarString;

    ProcessHandle(lua_State* L, ProcessOptions& opts, std::vector<std::string>& args, std::string context = "Process Spawn");

    void spawn(lua_State* L);
    void onHandleClose();
    void closePipe(std::unique_ptr<uvutils::PipeStream>& pipe);
    void closeHandles();
    static void onProcessExit(uv_process_t* process, int64_t exitStatus, int termSignal);
    void tryComplete(std::optional<std::string> errorMessage = std::nullopt);
    void completeProcessExecution();
};

} // namespace process
