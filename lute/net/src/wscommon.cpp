#include "wscommon.h"

#include "lualib.h"

namespace net
{

WebSocketPayload checkWebSocketPayload(lua_State* L, int index)
{
    if (lua_isstring(L, index))
    {
        size_t length = 0;
        const char* data = lua_tolstring(L, index, &length);
        return {data, length, false};
    }

    if (lua_isbuffer(L, index))
    {
        size_t length = 0;
        void* data = lua_tobuffer(L, index, &length);
        return {static_cast<const char*>(data), length, true};
    }

    luaL_typeerrorL(L, index, "string or buffer");
}

} // namespace net
