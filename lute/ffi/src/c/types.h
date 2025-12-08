#pragma once

#include "lua.h"
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