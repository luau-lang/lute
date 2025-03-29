#include "lute/process.h"
#include "lute/runtime.h"
#include <uv.h>
#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <map>

#include "lua.h"
#include "lualib.h"

namespace process {

struct ProcessHandle {
    uv_process_t process;
    uv_pipe_t stdout_pipe;
    uv_pipe_t stderr_pipe;
    uv_loop_t* loop = nullptr;
    std::string stdout_data;
    std::string stderr_data;
    int64_t exit_code = -1;
    int term_signal = 0;
    bool completed = false;
    ResumeToken resume_token;
    std::shared_ptr<ProcessHandle> self;
    std::atomic<int> pending_closes{0};

    ~ProcessHandle() {}

    void close_handles() {
        auto close_cb = [](uv_handle_t* handle) {
            ProcessHandle* ph = static_cast<ProcessHandle*>(handle->data);
            if (--ph->pending_closes == 0) {
                ph->self.reset();
            }
        };

        if (stdout_pipe.loop && uv_is_active((uv_handle_t*)&stdout_pipe)) {
            pending_closes++;
             uv_read_stop((uv_stream_t*)&stdout_pipe);
             uv_close((uv_handle_t*)&stdout_pipe, close_cb);
        }
         if (stderr_pipe.loop && uv_is_active((uv_handle_t*)&stderr_pipe)) {
            pending_closes++;
             uv_read_stop((uv_stream_t*)&stderr_pipe);
             uv_close((uv_handle_t*)&stderr_pipe, close_cb);
         }
         if (process.loop) {
            pending_closes++;
            uv_close((uv_handle_t*)&process, close_cb);
         }

        if (pending_closes == 0) {
            self.reset();
        }
    }

    void trigger_completion(bool success, const std::string& error_msg = "") {
        if (completed) return;
        completed = true;

        close_handles();

        if (!resume_token) {
            return;
        }

        if (success) {
            int64_t final_exit_code = exit_code;
            int final_term_signal = term_signal;
            std::string final_stdout = stdout_data;
            std::string final_stderr = stderr_data;
            std::string final_signal_str = final_term_signal ? std::to_string(final_term_signal) : "";

            resume_token->complete([=](lua_State* L) {
                lua_createtable(L, 0, 6); // ok, exitCode, stdout, stderr, signal, error

                bool ok = (final_exit_code == 0 && final_term_signal == 0);

                lua_pushboolean(L, ok);
                lua_setfield(L, -2, "ok");

                lua_pushinteger(L, final_exit_code);
                lua_setfield(L, -2, "exitCode");

                lua_pushlstring(L, final_stdout.c_str(), final_stdout.length());
                lua_setfield(L, -2, "stdout");

                lua_pushlstring(L, final_stderr.c_str(), final_stderr.length());
                lua_setfield(L, -2, "stderr");

                if (!final_signal_str.empty()) {
                    lua_pushstring(L, final_signal_str.c_str());
                } else {
                    lua_pushnil(L);
                }
                lua_setfield(L, -2, "signal");

                if (!ok) {
                    std::string err = final_signal_str.empty()
                        ? "Process exited with code " + std::to_string(final_exit_code)
                        : "Process terminated by signal " + final_signal_str;
                    lua_pushstring(L, err.c_str());
                } else {
                    lua_pushnil(L);
                }
                lua_setfield(L, -2, "error");

                return 1;
            });
        } else {
            resume_token->fail("Process error: " + error_msg);
        }

        resume_token.reset();
    }
};

static void on_process_exit(uv_process_t* process, int64_t exit_status, int term_signal) {
    ProcessHandle* handle = static_cast<ProcessHandle*>(process->data);
    if (!handle || handle->completed) return;

    handle->exit_code = exit_status;
    handle->term_signal = term_signal;

    handle->trigger_completion(true);
}

static void on_pipe_read(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf) {
    ProcessHandle* handle = static_cast<ProcessHandle*>(stream->data);

    if (!handle || handle->completed) {
        if (buf->base) free(buf->base);
        return;
    }

    if (nread > 0) {
        std::string* target_buffer = (stream == (uv_stream_t*)&handle->stdout_pipe)
            ? &handle->stdout_data
            : &handle->stderr_data;
        target_buffer->append(buf->base, nread);
    } else if (nread < 0) {
        if (nread != UV_EOF) {
            std::string error_details = (stream == (uv_stream_t*)&handle->stdout_pipe) ? "stdout" : "stderr";
            error_details += " read error: ";
            error_details += uv_strerror(nread);
            handle->trigger_completion(false, error_details);
        }
    }

    if (buf->base) {
        free(buf->base);
    }
}

static void alloc_buffer(uv_handle_t* handle, size_t suggested_size, uv_buf_t* buf) {
    size_t reasonable_size = std::min(suggested_size, (size_t)65536);
    buf->base = (char*)malloc(reasonable_size);
    buf->len = buf->base ? reasonable_size : 0;
    if (!buf->base && reasonable_size > 0) {
         fprintf(stderr, "Process pipe buffer allocation failed!\n");
    }
}

int create(lua_State* L) {
    std::vector<std::string> args;
    if (lua_istable(L, 1))
    {
        int len = lua_objlen(L, 1);
        for (int i = 1; i <= len; i++)
        {
            lua_rawgeti(L, 1, i);
            args.push_back(lua_tostring(L, -1));
            lua_pop(L, 1);
        }
    }
    else
    {
        args.push_back(lua_tostring(L, 1));
    }

    if (args.empty() || args[0].empty())
    {
        luaL_error(L, "process.create requires a non-empty command"); return 0;
    }
    bool use_shell = false; std::string cwd; std::map<std::string, std::string> env;
    if (lua_istable(L, 2))
    {
        lua_getfield(L, 2, "shell");
        if (!lua_isnil(L, -1))
            use_shell = lua_toboolean(L, -1);

        lua_pop(L, 1);
        
        lua_getfield(L, 2, "cwd"); 
        if (!lua_isnil(L, -1))
            cwd = lua_tostring(L, -1);

        lua_pop(L, 1);
        
        lua_getfield(L, 2, "env");
        if (lua_istable(L, -1))
        {
            lua_pushnil(L); 
            while (lua_next(L, -2))
            {
                env[luaL_checkstring(L, -2)] = luaL_checkstring(L, -1);
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
    }

    if (use_shell && args.size() > 1)
    {
        std::string cmd = args[0];
        
        for(size_t i=1; i<args.size(); ++i)
        {
            cmd += " ";
            cmd += args[i];
        }
        
        args = {cmd};
    }

    auto handle = std::make_shared<ProcessHandle>();
    handle->loop = uv_default_loop(); // Use the default libuv loop
    handle->self = handle; // Create self-reference to keep alive

    uv_process_options_t options = {};
    options.exit_cb = on_process_exit;
    options.file = args[0].c_str();

    std::vector<char*> process_args_ptr;
    for (const auto& arg : args) {
        process_args_ptr.push_back(const_cast<char*>(arg.c_str()));
    }
    process_args_ptr.push_back(nullptr);
    options.args = process_args_ptr.data();

    std::vector<std::string> env_strings;
    std::vector<char*> env_ptr;
    if (!env.empty()) {
        for (const auto& pair : env) {
            env_strings.push_back(pair.first + "=" + pair.second);
        }
        for (auto& str : env_strings) {
            env_ptr.push_back(&str[0]);
        }
        env_ptr.push_back(nullptr);
        options.env = env_ptr.data();
    }

    if (!cwd.empty()) {
        options.cwd = cwd.c_str();
    }

    uv_pipe_init(handle->loop, &handle->stdout_pipe, 0);
    uv_pipe_init(handle->loop, &handle->stderr_pipe, 0);
    options.stdio_count = 3;
    uv_stdio_container_t stdio[3];
    stdio[0].flags = UV_INHERIT_FD; stdio[0].data.fd = 0; // Inherit stdin
    stdio[1].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_READABLE_PIPE | UV_WRITABLE_PIPE); stdio[1].data.stream = (uv_stream_t*)&handle->stdout_pipe;
    stdio[2].flags = static_cast<uv_stdio_flags>(UV_CREATE_PIPE | UV_READABLE_PIPE | UV_WRITABLE_PIPE); stdio[2].data.stream = (uv_stream_t*)&handle->stderr_pipe;
    options.stdio = stdio;

    handle->process.data = handle.get();
    handle->stdout_pipe.data = handle.get();
    handle->stderr_pipe.data = handle.get();

    handle->resume_token = getResumeToken(L);

    int spawn_result = uv_spawn(handle->loop, &handle->process, &options);

    if (spawn_result != 0) {
        if (handle->resume_token) {
            handle->resume_token->runtime->releasePendingToken();
            handle->resume_token.reset();
        }
        handle->self.reset();
        handle->close_handles();

        lua_pushnil(L);
        lua_pushstring(L, uv_strerror(spawn_result));
        return 2;
    }

    uv_read_start((uv_stream_t*)&handle->stdout_pipe, alloc_buffer, on_pipe_read);
    uv_read_start((uv_stream_t*)&handle->stderr_pipe, alloc_buffer, on_pipe_read);

    return lua_yield(L, 0);
}

} // namespace process

int luaopen_process(lua_State* L)
{
    luaL_register(L, "process", process::lib);
    return 1;
}

int luteopen_process(lua_State* L)
{
    lua_createtable(L, 0, std::size(process::lib));

    for (auto& [name, func] : process::lib)
    {
        if (!name || !func)
            break;

        lua_pushcfunction(L, func, name);
        lua_setfield(L, -2, name);
    }

    lua_setreadonly(L, -1, 1);

    return 1;
}
