#include "debugfixture.h"

#include "lute/runtime.h"

#include <unistd.h>

DebugFixture::DebugFixture()
    : runtime(std::make_unique<Runtime>(getReporter()))
{
    setupState(*runtime, nullptr);
}

DebugFixture::~DebugFixture()
{
    if (!scriptPath.empty())
        ::unlink(scriptPath.c_str());
}

std::string DebugFixture::writeScript(const std::string& source)
{
    char tmpl[] = "/tmp/lute_debug_test_XXXXXX";
    int fd = ::mkstemp(tmpl);
    ::write(fd, source.c_str(), source.size());
    ::close(fd);
    scriptPath = tmpl;
    std::string luaPath = scriptPath + ".lua";
    ::rename(scriptPath.c_str(), luaPath.c_str());
    scriptPath = luaPath;
    return scriptPath;
}
