#include "cliruntimefixture.h"
#include "doctest.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "net_server_runtime_teardown_releases_uws_loop")
{
    CHECK(runCode(R"(
        local server = require("@lute/net/server")

        local instance = server.serve({
            port = 0,
            handler = function()
                return "ok"
            end,
        })

        instance.close()
    )"));
}
