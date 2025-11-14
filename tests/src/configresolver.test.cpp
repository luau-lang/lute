// Tests for configuration resolver inheritance and ambiguity.
#include "lute/configresolver.h"

#include "Luau/FileUtils.h"

#include "doctest.h"
#include "luteprojectroot.h"

TEST_CASE("configresolver")
{
    std::string root = getLuteProjectRootAbsolute();
    std::string baseDir = joinPaths(root, "tests/src/resolver");
    std::string file = joinPaths(baseDir, "mainmodule.luau");

    // There is a .luaurc in tests/src/resolver; verify resolver reads it without crashing
    Luau::LuteConfigResolver configResolver(Luau::Mode::Nonstrict);
    const Luau::Config& cfg = configResolver.getConfig(file, {});

    // check that mode was set to strict per .luaurc
    CHECK(cfg.mode == Luau::Mode::Strict);

    // check the alias root was set
    const Luau::Config::AliasInfo* aliasInfo = cfg.aliases.find("root");
    CHECK(aliasInfo != nullptr);
    CHECK(aliasInfo->value == "./");

    // run readConfigRec on parent directory to verify inheritance
    const Luau::Config& parentCfg = configResolver.readConfigRec(baseDir);
    // mode should be the same as child since no override
    CHECK(parentCfg.mode == Luau::Mode::Strict);
}
