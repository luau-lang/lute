#pragma once

#include "lua.h"

#include <cstddef>

namespace net
{

struct WebSocketPayload
{
    const char* data = nullptr;
    size_t length = 0;
    bool binary = false;
};

WebSocketPayload checkWebSocketPayload(lua_State* L, int index);

} // namespace net
