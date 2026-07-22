local test = require("@std/test")

local task = require("@lute/task")
local debug = require("@lute/debugger")
local path = require("@std/path")
local proc = require("@std/process")

-- a helper function that basically polls a boolean, since Luau does
-- not allow the promises/futures we use in the C++ tests
local function waitUntil(condition: () -> boolean, timeout: number?, pollInterval: number?): boolean
	local elapsed = 0
	local limit = timeout or 5
	local poll = pollInterval or 0.05
	while not condition() and elapsed < limit do
		task.wait(poll)
		elapsed += poll
	end
	return condition()
end

test.suite("LuteDebugLibrarySuite", function(suite)
	-- this test cause mainly checks launching and hitting breakpoints
	suite:case("launchAndHitBreakpoint", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local fixturePath = path.format(path.join(proc.cwd(), "tests/src/debug/loop.luau"))
		local bp = target:setBreakpoint(fixturePath, 6)
		check.eq(bp.id, 0)
		check.eq(bp.line, 6)
		check.eq(bp.sourcePath, fixturePath)
		check.eq(bp.status, "pendingInstall")
		local numHits, onFinished, numBreakpointsInstalled = 0, false, 0
		local targetLaunched = target:launch(fixturePath, {}, {
			onBreakpointHit = function(_bp)
				numHits += 1
				local continued = target:continueProcess()
				check.that(continued)
			end,
			onBreakpointInstall = function(_bp)
				numBreakpointsInstalled += 1
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.that(targetLaunched)
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		check.eq(numHits, 25)
		check.eq(numBreakpointsInstalled, 1)
	end)
	-- this test case focuses on adding, getting, and removing breakpoints
	suite:case("setAndRemove", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local fixturePath = path.format(path.join(proc.cwd(), "tests/src/debug/loop.luau"))
		local bp1 = target:setBreakpoint(fixturePath, 6)
		local bp2 = target:setBreakpoint(fixturePath, 7)
		local bp3 = target:setBreakpoint(fixturePath, 4)
		local bpGet = assert(target:getBreakpointById(bp1.id))
		check.eq(bpGet.id, bp1.id)
		check.eq(bpGet.line, 6)
		check.eq(bpGet.sourcePath, fixturePath)
		check.eq(bpGet.status, "pendingInstall")
		bpGet = assert(target:getBreakpointById(bp2.id))
		check.eq(bpGet.id, bp2.id)
		check.eq(bpGet.line, 7)
		check.eq(bpGet.sourcePath, fixturePath)
		check.eq(bpGet.status, "pendingInstall")
		bpGet = assert(target:getBreakpointById(bp3.id))
		check.eq(bpGet.id, bp3.id)
		check.eq(bpGet.line, 4)
		check.eq(bpGet.sourcePath, fixturePath)
		check.eq(bpGet.status, "pendingInstall")
		local bps = target:getBreakpoints()
		check.eq(#bps, 3)
		target:removeBreakpoint(bp1.id)
		bps = target:getBreakpoints()
		check.eq(#bps, 2)
		bpGet = target:getBreakpointById(bp1.id)
		check.eq(bpGet, nil)
		local numHitsBp2, numHitsBp3, onFinished, numBreakpointsUninstalled = 0, 0, false, 0
		local targetLaunched = target:launch(fixturePath, {}, {
			onBreakpointHit = function(bp)
				if bp.id == bp2.id then
					check.eq(bp.id, bp2.id)
					check.eq(bp.line, 7)
					check.eq(bp.sourcePath, fixturePath)
					check.eq(bp.status, "installed")
					numHitsBp2 += 1
					target:removeBreakpoint(bp.id)
					-- the removal should happen immediately given we are in paused state
					bps = target:getBreakpoints()
					check.eq(#bps, 1)
				else
					numHitsBp3 += 1
				end
				local continued = target:continueProcess()
				check.that(continued)
			end,
			onBreakpointUninstall = function(_bp)
				numBreakpointsUninstalled += 1
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.that(targetLaunched)
		-- we expect this breakpoint to be immediately installed
		bpGet = assert(target:getBreakpointById(bp3.id))
		check.eq(bpGet.id, bp3.id)
		check.eq(bpGet.line, 4)
		check.eq(bpGet.sourcePath, fixturePath)
		check.eq(bpGet.status, "installed")

		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		bps = target:getBreakpoints()
		check.eq(#bps, 1)
		check.eq(numHitsBp2, 1)
		check.eq(numHitsBp3, 5)
		check.eq(numBreakpointsUninstalled, 1)
	end)
	-- this test case checks bp actually pauses execution
	suite:case("pauseBp", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local fixturePath = path.format(path.join(proc.cwd(), "tests/src/debug/simple.luau"))
		local onFinished = false
		target:setBreakpoint(fixturePath, 2)
		local targetLaunched = target:launch(fixturePath, {}, {
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.that(targetLaunched)
		check.eq(
			waitUntil(function()
				return onFinished
			end, 1),
			false
		)
		local continued = target:continueProcess()
		check.that(continued)
		check.eq(
			waitUntil(function()
				return onFinished
			end, 1),
			true
		)
	end)
end)
