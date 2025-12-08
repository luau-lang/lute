#pragma once

#include "lute/runtime.h"

#include "Luau/Variant.h"

#include "uv.h"

#include <cstddef>
#include <string>

namespace uvutils
{

struct UvError
{
    UvError(int code);
    std::string toString() const;

    int code;
};

typedef int (*BufferWriter)(char* buffer, size_t* size);

// Abstracts away buffer management when getting strings from libuv functions.
Luau::Variant<std::string, UvError> getStringFromUv(BufferWriter bufferWriter, size_t initialBufferSize = 256);

// Cleanup functions for UV request types
template<typename ReqT>
void cleanup_uv_req(ReqT* req)
{
}

template<>
void cleanup_uv_req<uv_fs_t>(uv_fs_t* req);

// UVRequest - manages libuv request lifecycle with automatic cleanup
template<typename ReqT>
struct UVRequest
{
    UVRequest(lua_State* L)
        : token(getResumeToken(L))
    {
        req.data = this;
    }

    ReqT* get()
    {
        return &req;
    }
    const ReqT* get() const
    {
        return &req;
    }

    static UVRequest<ReqT>* from(ReqT* req)
    {
        return static_cast<UVRequest<ReqT>*>(req->data);
    }

    // Proxy to token->fail with format string support
    template<typename... Args>
    void fail(const char* fmt, Args&&... args)
    {
        // First, determine the required size
        int size = snprintf(nullptr, 0, fmt, std::forward<Args>(args)...);
        if (size < 0)
        {
            token->fail("Format error");
            return;
        }

        // Allocate buffer with exact size needed (+1 for null terminator)
        std::vector<char> buffer(size + 1);
        snprintf(buffer.data(), buffer.size(), fmt, std::forward<Args>(args)...);
        token->fail(std::string(buffer.data()));
    }

    // Proxy to token->complete
    void succeed(std::function<int(lua_State*)> cont)
    {
        token->complete(cont);
    }

    virtual ~UVRequest()
    {
        cleanup_uv_req(&req);
    }

    ResumeToken token;
    ReqT req;
};

} // namespace uvutils
