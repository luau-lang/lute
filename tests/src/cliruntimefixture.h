#pragma once
#include "lute/climain.h"
#include "lute/runtime.h"

#include "lutefixture.h"

#include "lua.h"

#include <memory>
#include <string>

class CliRuntimeFixture : public LuteFixture
{
public:
    CliRuntimeFixture();

    bool runCode(const std::string& source);

    lua_State* L;

private:
    std::unique_ptr<Runtime> runtime;
};
