#include <csetjmp>
#include <memory>

#include "ffi.h"

#include "lua.h"
#include "lualib.h"

#include "lute/userdatas.h"

#include "ctypes.h"
#include "functions.h"

namespace ffi::cffi
{
CFunction::CFunction(void (*functionPointer)(), FunctionInfo info)
    : functionPointer{functionPointer}
    , functionInfo{std::move(info)}
{
    const size_t argCount = functionInfo.argumentTypes.size();

    argumentValues.reserve(argCount);
    for (size_t i = 0; i < argCount; ++i)
    {
        argumentValues.push_back(
            std::make_unique<ffi_arg[]>(ffiArgSlotsForSize(functionInfo.argumentTypes[i]->type.size))
        );
    }

    returnValue = std::make_unique<ffi_arg[]>(ffiArgSlotsForSize(functionInfo.returnType->type.size));

    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, static_cast<unsigned int>(argCount), &functionInfo.returnType->type, functionInfo.argumentTypePointers.get());
}

CFunction::~CFunction()
{
    // vector handles cleanup automatically
}

int CFunction::luaCall(lua_State* L)
{
    CallState state;
    const size_t argCount = functionInfo.argumentTypes.size();

    for (size_t i = 0; i < argCount; ++i)
    {
        functionInfo.argumentTypes[i]->serialize(L, static_cast<int>(i + 1), argumentValues[i].get(), state);
    }

    if (setjmp(state.errorBuffer) != 0)
    {
        lua_error(L);
        return 0;
    }

    // Create temporary array of pointers for ffi_call
    std::vector<void*> argPointers;
    argPointers.reserve(argCount);
    for (size_t i = 0; i < argCount; ++i)
    {
        argPointers.push_back(argumentValues[i].get());
    }

    ffi_call(&cif, functionPointer, returnValue.get(), argPointers.data());

    return functionInfo.returnType->deserialize(L, returnValue.get());
}

static int call(lua_State* L)
{
    auto* cfunc = static_cast<CFunction*>(lua_touserdatatagged(L, lua_upvalueindex(1), kCFunctionTag));
    return cfunc->luaCall(L);
}

int CFunction::pushCFunction(lua_State* L, const char* name)
{
    new (lua_newuserdatatagged(L, sizeof(CFunction), kCFunctionTag)) CFunction{functionPointer, std::move(functionInfo)};

    lua_pushcclosure(L, call, name, 1);
    return 1;
}

int CFunctionType::deserialize(lua_State* L, const ffi_arg* data)
{
    return CFunction{FFI_FN(*data), functionInfo}.pushCFunction(L, nullptr);
}

struct LuaClosureContext
{
    LuaClosureContext(lua_State* inL, int inFunctionRef, FunctionInfo* inFunctionInfo, CallState* inState, std::jmp_buf* inJumpBuffer)
        : L{inL}
        , functionRef{inFunctionRef}
        , functionInfo{inFunctionInfo}
        , state{inState}
        , jumpBuffer{inJumpBuffer}
    {
    }

    lua_State* L;
    int functionRef;
    FunctionInfo* functionInfo;
    CallState* state;
    std::jmp_buf* jumpBuffer;
    ffi_cif cif;
};

static void closureTrampoline(ffi_cif* cif, void* ret, void** args, void* userdata)
{
    auto* data = static_cast<LuaClosureContext*>(userdata);
    lua_State* L = data->L;

    lua_getref(L, data->functionRef);

    const int argCount = static_cast<int>(data->functionInfo->argumentTypes.size());
    for (int i = 0; i < argCount; ++i)
    {
        data->functionInfo->argumentTypes[i]->deserialize(L, reinterpret_cast<const ffi_arg*>(args[i]));
    }

    const int nresults = (data->cif.rtype->type != FFI_TYPE_VOID) ? 1 : 0;
    const int status = lua_pcall(L, argCount, nresults, 0);
    if (status != LUA_OK)
    {
        std::longjmp(*data->jumpBuffer, 1);
        return;
    }

    if (data->cif.rtype->type != FFI_TYPE_VOID)
    {
        data->functionInfo->returnType->serialize(L, -1, reinterpret_cast<ffi_arg*>(ret), *data->state);
        lua_pop(L, 1);
    }
}

void CFunctionType::serialize(lua_State* L, int index, ffi_arg* to, CallState& state)
{
    luaL_checktype(L, index, LUA_TFUNCTION);

    lua_pushvalue(L, index);
    int functionRef = lua_ref(L, -1);
    lua_pop(L, 1);

    auto* userData = state.create<LuaClosureContext>(LuaClosureContext{L, functionRef, &functionInfo, &state, &state.errorBuffer});

    ffi_status status = ffi_prep_cif(
        &userData->cif, FFI_DEFAULT_ABI, functionInfo.argumentTypes.size(), &functionInfo.returnType->type, functionInfo.argumentTypePointers.get()
    );

    if (status != FFI_OK)
    {
        luaL_error(L, "Failed to prepare ffi_cif for closure");
    }

    void* boundFunction = nullptr;
    auto closure = state.create<std::unique_ptr<ffi_closure, decltype(&ffi_closure_free)>>(
        static_cast<ffi_closure*>(ffi_closure_alloc(sizeof(ffi_closure), &boundFunction)), ffi_closure_free
    );

    if (!closure)
    {
        luaL_error(L, "Failed to allocate ffi_closure");
    }

    status = ffi_prep_closure_loc(closure->get(), &userData->cif, closureTrampoline, userData, boundFunction);

    if (status != FFI_OK)
    {
        ffi_closure_free(closure);
        luaL_error(L, "Failed to prepare ffi_closure");
    }

    std::memcpy(to, &boundFunction, sizeof(void*));
}

static int cFunctionIncomplete(lua_State* L)
{
    int argCount = lua_gettop(L);
    std::vector<UserdataReference<CType>> collectedTypes;

    for (int i = 0; i < argCount; ++i)
    {
        collectedTypes.push_back(UserdataReference<CType>{L, 1 + i});
    }

    auto returnType = UserdataReference<CType>{L, lua_upvalueindex(1)};

    new (lua_newuserdatataggedwithmetatable(L, sizeof(CFunctionType), kCTypeTag))
        CFunctionType{FunctionInfo{std::move(collectedTypes), std::move(returnType)}};

    return 1;
}

int newCFunction(lua_State* L)
{
    luaL_checkudata(L, 1, "ctype");

    lua_pushcclosure(L, cFunctionIncomplete, "cfunctionbuilder", 1);

    return 1;
}


} // namespace ffi::cffi