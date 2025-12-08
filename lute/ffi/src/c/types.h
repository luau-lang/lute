#pragma once

#include "lua.h"
#include "lualib.h"
#include "ffi.h"

#include <csetjmp>
#include <functional>
#include <vector>

class CallState
{
public:
    ~CallState()
    {
        for (const auto& callback : callbacks)
        {
            callback();
        }
    }

    template<typename T, typename... Args>
    T* create(Args&&... args)
    {
        T* ptr = new T(std::forward<Args>(args)...);

        callbacks.push_back(
            [ptr]()
            {
                delete ptr;
            }
        );

        return ptr;
    }

    void jumpToError()
    {
        std::longjmp(errorBuffer, 1);
    }

    std::jmp_buf errorBuffer;
private:
    std::vector<std::function<void()>> callbacks;
};

template<typename T>
class UserdataReference
{
public:
    UserdataReference(lua_State* L, int index)
    {
        this->L = L;
        obj = static_cast<T*>(luaL_checkudata(L, index, T::metatableName));
        ref = lua_ref(L, index);
    }

    ~UserdataReference()
    {
        lua_unref(L, ref);
    }

    UserdataReference(const UserdataReference& other)
        : L{other.L}
        , obj{other.obj}
    {
        lua_getref(L, ref);

        ref = lua_ref(L, -1);

        lua_pop(L, 1);
    }

    UserdataReference& operator=(const UserdataReference& other)
    {
        if (this != &other)
        {
            lua_getref(other.L, other.ref);
            int newRef = lua_ref(other.L, -1);
            lua_pop(other.L, 1);

            lua_unref(L, ref);

            L = other.L;
            obj = other.obj;
            ref = newRef;
        }

        return *this;
    }

    UserdataReference(UserdataReference&& other) noexcept
        : L{other.L}
        , obj{other.obj}
        , ref{other.ref}
    {
        other.ref = LUA_NOREF;
    }

    UserdataReference& operator=(UserdataReference&& other) noexcept
    {
        if (this != &other)
        {
            lua_unref(L, ref);

            L = other.L;
            obj = other.obj;
            ref = other.ref;

            other.ref = LUA_NOREF;
        }

        return *this;
    }

    T* operator->()
    {
        return obj;
    }

    const T* operator->() const
    {
        return obj;
    }

    T* get()
    {
        return obj;
    }

    const T* get() const
    {
        return obj;
    }

private:
    lua_State* L;
    T* obj;
    int ref = LUA_NOREF;
};


class CType
{
public:
    static constexpr const char* metatableName = "ctype";

    virtual ~CType() = default;

    ffi_type type;

    virtual int deserialize(lua_State* L, const ffi_arg* data) = 0;
    virtual void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) = 0;
    virtual bool isSymbolPointer() const = 0;
};