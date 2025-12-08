#pragma once

#include "lua.h"

#include <memory>

struct lua_State;


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
    int ref;
};

struct Ref
{
    Ref(lua_State* L, int idx);
    ~Ref();
    Ref(Ref&& rhs) noexcept = delete;
    Ref& operator=(Ref&& rhs) noexcept = delete;
    Ref(const Ref& rhs) = delete;
    Ref& operator=(const Ref& rhs) = delete;

    void push(lua_State* L) const;

    lua_State* GL = nullptr;
    int refId = 0;
};

std::shared_ptr<Ref> getRefForThread(lua_State* L);
