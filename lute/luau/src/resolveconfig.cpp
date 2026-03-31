#include "lute/resolveconfig.h"

#include "lute/configresolver.h"

#include "Luau/Config.h"
#include "Luau/FileUtils.h"
#include "Luau/LinterConfig.h"

#include "lua.h"
#include "lualib.h"

#include <string>

static const char* modeToString(Luau::Mode mode)
{
    switch (mode)
    {
    case Luau::Mode::NoCheck:
        return "nocheck";
    case Luau::Mode::Nonstrict:
        return "nonstrict";
    case Luau::Mode::Strict:
        return "strict";
    case Luau::Mode::Definition:
        return "definition";
    }
    return "nonstrict";
}

static void pushLintOptions(lua_State* L, const Luau::LintOptions& lintOptions)
{
    lua_createtable(L, 0, 0);
    for (int i = 1; i < static_cast<int>(Luau::LintWarning::Code__Count); i++)
    {
        auto code = static_cast<Luau::LintWarning::Code>(i);
        if (lintOptions.isEnabled(code))
        {
            lua_pushboolean(L, 1);
            lua_setfield(L, -2, Luau::kWarningNames[i]);
        }
    }
}

// Public API
Luau::Config resolveConfig(const std::string& filePath, std::vector<std::pair<std::string, std::string>>* configErrors)
{
    Luau::LuteConfigResolver configResolver(Luau::Mode::Nonstrict);

    std::optional<std::string> parentPath = getParentPath(filePath);
    if (!parentPath)
        return configResolver.defaultConfig;

    Luau::Config config = configResolver.readConfigRec(*parentPath);

    if (configErrors)
        *configErrors = std::move(configResolver.configErrors);

    return config;
}

int resolveConfig_luau(lua_State* L)
{
    std::string filePath = luaL_checkstring(L, 1);

    std::vector<std::pair<std::string, std::string>> configErrors;
    const Luau::Config config = resolveConfig(filePath, &configErrors);

    // result table
    lua_createtable(L, 0, 8);

    // languageMode
    lua_pushstring(L, modeToString(config.mode));
    lua_setfield(L, -2, "languageMode");

    // aliases: { [string]: { value: string, originalCase: string } }
    lua_createtable(L, 0, 0);
    for (auto it = config.aliases.begin(); it != config.aliases.end(); ++it)
    {
        const auto& [key, aliasInfo] = *it;
        if (key.empty())
            continue;
        lua_createtable(L, 0, 2);
        lua_pushlstring(L, aliasInfo.value.c_str(), aliasInfo.value.size());
        lua_setfield(L, -2, "value");
        lua_pushlstring(L, aliasInfo.originalCase.c_str(), aliasInfo.originalCase.size());
        lua_setfield(L, -2, "originalCase");
        lua_setfield(L, -2, key.c_str());
    }
    lua_setfield(L, -2, "aliases");

    // lintErrors
    lua_pushboolean(L, config.lintErrors);
    lua_setfield(L, -2, "lintErrors");

    // typeErrors
    lua_pushboolean(L, config.typeErrors);
    lua_setfield(L, -2, "typeErrors");

    // globals
    lua_createtable(L, static_cast<int>(config.globals.size()), 0);
    for (size_t i = 0; i < config.globals.size(); i++)
    {
        lua_pushlstring(L, config.globals[i].c_str(), config.globals[i].size());
        lua_rawseti(L, -2, static_cast<int>(i + 1));
    }
    lua_setfield(L, -2, "globals");

    // enabledLint: { [warningName]: true }
    pushLintOptions(L, config.enabledLint);
    lua_setfield(L, -2, "enabledLint");

    // fatalLint: { [warningName]: true }
    pushLintOptions(L, config.fatalLint);
    lua_setfield(L, -2, "fatalLint");

    // configErrors
    if (!configErrors.empty())
    {
        lua_createtable(L, static_cast<int>(configErrors.size()), 0);
        for (size_t i = 0; i < configErrors.size(); i++)
        {
            lua_createtable(L, 0, 2);
            lua_pushlstring(L, configErrors[i].first.c_str(), configErrors[i].first.size());
            lua_setfield(L, -2, "path");
            lua_pushlstring(L, configErrors[i].second.c_str(), configErrors[i].second.size());
            lua_setfield(L, -2, "message");
            lua_rawseti(L, -2, static_cast<int>(i + 1));
        }
        lua_setfield(L, -2, "configErrors");
    }

    return 1;
}
