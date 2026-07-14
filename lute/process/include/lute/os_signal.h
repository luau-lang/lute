#pragma once

#include "lute/runtime.h"

#include "lua.h"

#include "uv.h"

#include <functional>
#include <memory>


namespace process
{

struct SignalHandle
{
    SignalHandle(uv_loop_t* loop, int signum, std::function<void()> callback);


    ~SignalHandle();

    void close();

private:
    std::function<void()> callback;
    bool isClosed = false;
    std::unique_ptr<uv_signal_t> uvHandle;
};

int signalFunc(lua_State* L);

} // namespace process

void registerSignalHandle(lua_State* L);
