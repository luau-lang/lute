#pragma once
#include "lute/climain.h"
#include "lute/runtime.h"

#include "lua.h"

#include <memory>
#include <string>

#include "doctest.h"

class CliRuntimeFixture
{
public:
    CliRuntimeFixture();

    std::string getCapturedOutput();

    bool runCode(const std::string& source);

    lua_State* L;

private:
    std::unique_ptr<Runtime> runtime;
};