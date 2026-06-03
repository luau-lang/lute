#pragma once

#include "lute/runtime.h"

#include "uv.h"

#include <cstddef>
#include <string>
#include <vector>

namespace uvutils
{

template<typename... Args>
std::string formatUVError(const char* fmt, Args... args)
{
    int size = snprintf(nullptr, 0, fmt, args...);
    if (size < 0)
        return "Format error";
    std::vector<char> buffer(size + 1);
    snprintf(buffer.data(), buffer.size(), fmt, args...);
    return std::string(buffer.data());
}

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

    template<typename... Args>
    void fail(const char* fmt, Args&&... args)
    {
        token->fail(formatUVError(fmt, std::forward<Args>(args)...));
    }

    template<typename F>
    void succeed(F&& cont)
    {
        token->complete(std::forward<F>(cont));
    }

    void succeedTrivially()
    {
        succeed([](lua_State* L) { return 0; });
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
        // The libuv request struct retains a raw pointer to this object via req->data.
        // Releasing here intentionally leaks so the object stays alive until the callback fires.
        // The callback must call retake() to reclaim ownership; the destructor then runs after
        // the Luau coroutine has been scheduled to resume.
        ptr.release();
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
