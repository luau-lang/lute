#include "cliruntimefixture.h"
#include "doctest.h"

#include <string>

static bool hasReportedErrorContaining(TestReporter& reporter, const std::string& needle)
{
    for (const std::string& error : reporter.getErrors())
    {
        if (error.find(needle) != std::string::npos)
            return true;
    }

    return false;
}

TEST_CASE_FIXTURE(CliRuntimeFixture, "server_reports_http_and_upgrade_handler_errors")
{
    bool ok = runCode(R"(
        local net = require("@std/net")
        local server = require("@lute/net/server")
        local task = require("@lute/task")

        local syncInstance = server.serve({
            port = 0,
            handler = function()
                error("sync-http-boom")
            end,
        })

        local syncResponse = net.request(`http://{syncInstance.hostname}:{syncInstance.port}/`)
        if syncResponse.status ~= 500 then
            error(`expected 500, got {syncResponse.status}`)
        end
        if not string.find(syncResponse.body, "sync-http-boom", 1, true) then
            error(`missing error body: {syncResponse.body}`)
        end

        syncInstance.close()

        local yieldedInstance = server.serve({
            port = 0,
            handler = function()
                task.wait()
                error("yielded-http-boom")
            end,
        })

        local yieldedResponse = net.request(`http://{yieldedInstance.hostname}:{yieldedInstance.port}/`)
        if yieldedResponse.status ~= 500 then
            error(`expected 500, got {yieldedResponse.status}`)
        end
        if not string.find(yieldedResponse.body, "yielded-http-boom", 1, true) then
            error(`missing error body: {yieldedResponse.body}`)
        end

        yieldedInstance.close()

        local upgradeErrorInstance = server.serve({
            port = 0,
            handler = function()
                error("upgrade-http-boom")
            end,
            websocket = {},
        })

        local upgradeErrorResponse = net.request(`http://{upgradeErrorInstance.hostname}:{upgradeErrorInstance.port}/`, {
            headers = {
                Connection = "Upgrade",
                Upgrade = "websocket",
                ["Sec-WebSocket-Key"] = "dGhlIHNhbXBsZSBub25jZQ==",
                ["Sec-WebSocket-Version"] = "13",
            },
        })
        if upgradeErrorResponse.status ~= 500 then
            error(`expected 500, got {upgradeErrorResponse.status}`)
        end
        if not string.find(upgradeErrorResponse.body, "upgrade-http-boom", 1, true) then
            error(`missing error body: {upgradeErrorResponse.body}`)
        end

        upgradeErrorInstance.close()

        local upgradeYieldHttpInstance = server.serve({
            port = 0,
            handler = function()
                task.wait()

                return {
                    status = 200,
                    body = "upgrade-yield-ok",
                }
            end,
            websocket = {},
        })

        local upgradeYieldHttpResponse = net.request(`http://{upgradeYieldHttpInstance.hostname}:{upgradeYieldHttpInstance.port}/`, {
            headers = {
                Connection = "Upgrade",
                Upgrade = "websocket",
                ["Sec-WebSocket-Key"] = "dGhlIHNhbXBsZSBub25jZQ==",
                ["Sec-WebSocket-Version"] = "13",
            },
        })
        if upgradeYieldHttpResponse.status ~= 200 then
            error(`expected 200, got {upgradeYieldHttpResponse.status}`)
        end
        if upgradeYieldHttpResponse.body ~= "upgrade-yield-ok" then
            error(`expected yielded upgrade response, got {upgradeYieldHttpResponse.body}`)
        end

        upgradeYieldHttpInstance.close()

        local lateUpgradeInstance = server.serve({
            port = 0,
            handler = function(req, current)
                task.wait()
                current:upgrade(req)
                return "late upgrade unexpectedly continued"
            end,
            websocket = {},
        })

        local lateUpgradeResponse = net.request(`http://{lateUpgradeInstance.hostname}:{lateUpgradeInstance.port}/`, {
            headers = {
                Connection = "Upgrade",
                Upgrade = "websocket",
                ["Sec-WebSocket-Key"] = "dGhlIHNhbXBsZSBub25jZQ==",
                ["Sec-WebSocket-Version"] = "13",
            },
        })
        if lateUpgradeResponse.status ~= 500 then
            error(`expected 500, got {lateUpgradeResponse.status}`)
        end
        if not string.find(lateUpgradeResponse.body, "request.upgrade cannot be called after handler yields", 1, true) then
            error(`missing late upgrade error body: {lateUpgradeResponse.body}`)
        end

        lateUpgradeInstance.close()
    )");

    CHECK(ok);
    CHECK(hasReportedErrorContaining(getReporter(), "sync-http-boom"));
    CHECK(hasReportedErrorContaining(getReporter(), "yielded-http-boom"));
    CHECK(hasReportedErrorContaining(getReporter(), "upgrade-http-boom"));
    CHECK(hasReportedErrorContaining(getReporter(), "request.upgrade cannot be called after handler yields"));
    CHECK(!hasReportedErrorContaining(getReporter(), "websocket upgrade handler cannot yield"));
}
