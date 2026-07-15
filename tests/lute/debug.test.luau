local test = require("@std/test")

local task = require("@lute/task")
local debug = require("@lute/debug")
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
	suite:case("launchAndHitBreakpoint", function(assert)
		local target = debug.newTarget()
		assert.eq(typeof(target), "Target")
		local fixturePath = path.format(path.join(proc.cwd(), "tests/src/debug/loop.luau"))
		local bp = target:setBreakpoint(fixturePath, 6)
		assert.eq(bp.id, 0)
		assert.eq(bp.line, 6)
		assert.eq(bp.sourcePath, fixturePath)
		assert.eq(bp.status, "pendingInstall")
		local numHits, onFinished, numBreakpointsInstalled = 0, false, 0
		local targetLaunched = target:launch(fixturePath, {}, {
			onBreakpointHit = function(bp)
				numHits += 1
				target:continueProcess()
			end,
			onBreakpointInstall = function(bp)
				numBreakpointsInstalled += 1
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		assert.eq(targetLaunched, true)
		assert.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		assert.eq(numHits, 25)
		assert.eq(numBreakpointsInstalled, 1)
	end)
	-- this test case focuses on adding, getting, and removing breakpoints
	suite:case("setAndRemove", function(assert)
		local target = debug.newTarget()
		assert.eq(typeof(target), "Target")
		local fixturePath = path.format(path.join(proc.cwd(), "tests/src/debug/loop.luau"))
		local bp1 = target:setBreakpoint(fixturePath, 6)
		local bp2 = target:setBreakpoint(fixturePath, 7)
		local bp3 = target:setBreakpoint(fixturePath, 4)
		local bpGet = target:getBreakpointById(bp1.id)
		assert.eq(bpGet.id, bp1.id)
		assert.eq(bpGet.line, 6)
		assert.eq(bpGet.sourcePath, fixturePath)
		assert.eq(bpGet.status, "pendingInstall")
		bpGet = target:getBreakpointById(bp2.id)
		assert.eq(bpGet.id, bp2.id)
		assert.eq(bpGet.line, 7)
		assert.eq(bpGet.sourcePath, fixturePath)
		assert.eq(bpGet.status, "pendingInstall")
		bpGet = target:getBreakpointById(bp3.id)
		assert.eq(bpGet.id, bp3.id)
		assert.eq(bpGet.line, 4)
		assert.eq(bpGet.sourcePath, fixturePath)
		assert.eq(bpGet.status, "pendingInstall")
		local bps = target:getBreakpoints()
		assert.eq(#bps, 3)
		target:removeBreakpoint(bp1.id)
		bps = target:getBreakpoints()
		assert.eq(#bps, 2)
		bpGet = target:getBreakpointById(bp1.id)
		assert.eq(bpGet, nil)
		local numHitsBp2, numHitsBp3, onFinished, numBreakpointsUninstalled = 0, 0, false, 0
		local targetLaunched = target:launch(fixturePath, {}, {
			onBreakpointHit = function(bp)
				if bp.id == bp2.id then
					assert.eq(bp.id, bp2.id)
					assert.eq(bp.line, 7)
					assert.eq(bp.sourcePath, fixturePath)
					assert.eq(bp.status, "installed")
					numHitsBp2 += 1
					target:removeBreakpoint(bp.id)
					-- the removal should happen immediately given we are in paused state
					bps = target:getBreakpoints()
					assert.eq(#bps, 1)
				else
					numHitsBp3 += 1
				end
				target:continueProcess()
			end,
			onBreakpointUninstall = function(bp)
				numBreakpointsUninstalled += 1
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		assert.eq(targetLaunched, true)
		-- we expect this breakpoint to be immediately installed
		bpGet = target:getBreakpointById(bp3.id)
		assert.eq(bpGet.id, bp3.id)
		assert.eq(bpGet.line, 4)
		assert.eq(bpGet.sourcePath, fixturePath)
		assert.eq(bpGet.status, "installed")

		assert.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		bps = target:getBreakpoints()
		assert.eq(#bps, 1)
		assert.eq(numHitsBp2, 1)
		assert.eq(numHitsBp3, 5)
		assert.eq(numBreakpointsUninstalled, 1)
	end)
end)
