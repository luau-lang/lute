#pragma once

#include "lute/runtime.h"

#include "uv.h"

#include <cstddef>
#include <string>

namespace uvutils
{

template<typename ReqT>
void cleanup_uv_req(ReqT* req)
{
}

template<>
void cleanup_uv_req<uv_fs_t>(uv_fs_t* req);

// Free template function to recover type
template<typename T, typename ReqT>
std::unique_ptr<T> retake(ReqT* req)
{
    return std::unique_ptr<T>(static_cast<T*>(req->data));
}

template<typename ReqT>
struct UVRequest
{
    UVRequest(lua_State* L)
        : token(getResumeToken(L))
        , loop(getRuntimeLoop(L))
    {
        req.data = this;
    }

    UVRequest(const UVRequest&) = delete;
    UVRequest& operator=(const UVRequest&) = delete;
    UVRequest(UVRequest&&) = delete;
    UVRequest& operator=(UVRequest&&) = delete;

    // Proxy to token->fail with format string support
    template<typename... Args>
    void fail(const char* fmt, Args&&... args)
    {
        // First, determine the required size
        int size = snprintf(nullptr, 0, fmt, std::forward<Args>(args)...);
        if (size < 0)
        {
            token->fail("Format error in fail");
            return;
        }

        // Allocate buffer with exact size needed (+1 for null terminator)
        std::vector<char> buffer(size + 1);
        snprintf(buffer.data(), buffer.size(), fmt, std::forward<Args>(args)...);
        token->fail(std::string(buffer.data()));
    }

    template<typename F>
    void succeed(F&& cont)
    {
        token->complete(std::forward<F>(cont));
    }

    ~UVRequest()
    {
        cleanup_uv_req(&req);
    }

    uv_loop_t* getLoop()
    {
        return loop;
    }

    ResumeToken token;
    ReqT req;
    uv_loop_t* loop;
};


template<typename T>
struct ScopedUVRequest
{

    ScopedUVRequest(std::unique_ptr<T> req)
        : ptr(std::move(req))
    {
    }

    // Constructor that creates the unique_ptr from arguments
    template<typename... Args>
    explicit ScopedUVRequest(Args&&... args)
        : ptr(std::make_unique<T>(std::forward<Args>(args)...))
    {
    }

    ~ScopedUVRequest()
    {
        // The actual libuv C request struct retains a pointer to the request in the data field.
        // If we don't call release, this unique_pointer will be freed at the end of the scope that
        // contains the request, when we actually want this to be freed inside the asynchronously called callback.
        // The user should then take ownership of the request from the data via `retake` and the destructr
        // will automatically be invoked after we've scheduled the Luau code to resume
        if (ptr)
        {
            ptr.release();
        }
    }

    // Non-copyable and non-movable to prevent accidental double-release
    ScopedUVRequest(const ScopedUVRequest&) = delete;
    ScopedUVRequest& operator=(const ScopedUVRequest&) = delete;
    ScopedUVRequest(ScopedUVRequest&&) = delete;
    ScopedUVRequest& operator=(ScopedUVRequest&&) = delete;

    T* get() const
    {
        return ptr.get();
    }

    T* operator->() const
    {
        return ptr.get();
    }

    std::unique_ptr<T> ptr;
};

} // namespace uvutils
