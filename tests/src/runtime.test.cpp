#include "cliruntimefixture.h"
#include "doctest.h"

TEST_CASE_FIXTURE(CliRuntimeFixture, "runtime_will_not_resume_cancelled_task_spawn")
{
    runCode(R"(
        local task = require("@std/task")
        local t = task.spawn(function()
            task.wait(2)
        end)

        task.cancel(t)
    )");

    auto reporter = getReporter();
    for (auto s : reporter.getErrors())
    {
        auto idx = s.find("cannot resume dead coroutine");
        CHECK(idx == std::string::npos);
    }
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "server_serve_shuts_down_loop_cleanly")
{
    bool ok = runCode(R"(
        local net = require("@std/net")
        local server = require("@lute/net/server")

        local instance = server.serve({
            port = 0,
            handler = function(_req)
                return { status = 200, body = "" }
            end,
        })

        local response = net.request(`{instance.hostname}:{instance.port}`, { method = "GET" })
        assert(response.ok)

        instance.close()
    )");

    CHECK(ok);
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "multiple_server_serve_calls_shut_down_cleanly")
{
    bool ok = runCode(R"(
        local net = require("@std/net")
        local server = require("@lute/net/server")

        local a = server.serve({ port = 0, handler = function(_req) return { status = 200, body = "" } end })
        local b = server.serve({ port = 0, handler = function(_req) return { status = 200, body = "" } end })

        assert(net.request(`{a.hostname}:{a.port}`, { method = "GET" }).ok)
        assert(net.request(`{b.hostname}:{b.port}`, { method = "GET" }).ok)

        a.close()
        b.close()
    )");

    CHECK(ok);
}
