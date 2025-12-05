#pragma once

#include <memory>
#include <vector>

#include "ffi.h"
#include "types.h"

namespace ffi::cffi
{

struct FunctionInfo
{
    FunctionInfo(std::vector<UserdataReference<CType>> argTypes, UserdataReference<CType> retType)
        : argumentTypes{std::move(argTypes)}
        , returnType{std::move(retType)}
    {
        argumentTypePointers = std::make_unique<ffi_type*[]>(argumentTypes.size() + 1);
        for (size_t i = 0; i < argumentTypes.size(); ++i)
        {
            argumentTypePointers[i] = &argumentTypes[i]->type;
        }
        argumentTypePointers[argumentTypes.size()] = nullptr;
    }

    FunctionInfo(const FunctionInfo& other)
        : FunctionInfo(other.argumentTypes, other.returnType) {};
    FunctionInfo& operator=(const FunctionInfo& other)
    {
        if (this != &other)
        {
            std::vector<UserdataReference<CType>> newArgTypes;
            for (const auto& argType : other.argumentTypes)
            {
                newArgTypes.push_back(argType);
            }
            UserdataReference<CType> newRetType = other.returnType;

            argumentTypes = std::move(newArgTypes);
            returnType = std::move(newRetType);

            argumentTypePointers = std::make_unique<ffi_type*[]>(argumentTypes.size() + 1);
            for (size_t i = 0; i < argumentTypes.size(); ++i)
            {
                argumentTypePointers[i] = &argumentTypes[i]->type;
            }
            argumentTypePointers[argumentTypes.size()] = nullptr;
        }
        return *this;
    };

    FunctionInfo(FunctionInfo&&) = default;
    FunctionInfo& operator=(FunctionInfo&&) = default;

    std::vector<UserdataReference<CType>> argumentTypes;
    UserdataReference<CType> returnType;
    std::unique_ptr<ffi_type*[]> argumentTypePointers;
};

class CFunctionType;

class CFunction
{
public:
    CFunction(void (*functionPointer)(), FunctionInfo functionInfo);

    ~CFunction();

    int luaCall(lua_State* L);
    int pushCFunction(lua_State* L, void (*functionPointer)(), const char* name);

private:
    void (*functionPointer)();
    ffi_cif cif;

    FunctionInfo functionInfo;
    /// storage for argument values during a call
    std::unique_ptr<ffi_arg*[]> argumentValues;
    /// storage for return value during a call
    std::unique_ptr<ffi_arg[]> returnValue;
};

class CFunctionType : public CType
{
public:
    CFunctionType(FunctionInfo functionInfo)
        : functionInfo{std::move(functionInfo)}
    {
        type = ffi_type_pointer;
    }


    int deserialize(lua_State* L, const ffi_arg* data) override;
    void serialize(lua_State* L, int index, ffi_arg* to, CallState& state) override;

    FunctionInfo functionInfo;
};

} // namespace ffi::cffi