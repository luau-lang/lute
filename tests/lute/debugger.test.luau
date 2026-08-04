local test = require("@std/test")

local task = require("@lute/task")
local debug = require("@lute/debugger")
local path = require("@std/path")
local proc = require("@std/process")

local function normalizePath(p: string): string
	return (p:gsub("\\", "/"))
end

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
		check.eq(bp.id, 1)
		check.eq(bp.line, 6)
		check.eq(bp.sourcePath, normalizePath(fixturePath))
		check.eq(bp.status, "pendingInstall")
		local numHits, onFinished, numBreakpointsInstalled = 0, false, 0
		local targetLaunched = target:launch(fixturePath, {}, {
			onBreakpointHit = function(_thread, _bp)
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
		check.eq(targetLaunched, nil)
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
		check.eq(bpGet.sourcePath, normalizePath(fixturePath))
		check.eq(bpGet.status, "pendingInstall")
		bpGet = assert(target:getBreakpointById(bp2.id))
		check.eq(bpGet.id, bp2.id)
		check.eq(bpGet.line, 7)
		check.eq(bpGet.sourcePath, normalizePath(fixturePath))
		check.eq(bpGet.status, "pendingInstall")
		bpGet = assert(target:getBreakpointById(bp3.id))
		check.eq(bpGet.id, bp3.id)
		check.eq(bpGet.line, 4)
		check.eq(bpGet.sourcePath, normalizePath(fixturePath))
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
			onBreakpointHit = function(_thread, bp)
				if bp.id == bp2.id then
					check.eq(bp.id, bp2.id)
					check.eq(bp.line, 7)
					check.eq(bp.sourcePath, normalizePath(fixturePath))
					check.eq(bp.status, "installed")
					numHitsBp2 += 1
					check.eq(#target:getBreakpointsByStatus("installed"), 2)
					check.eq(#target:getBreakpointsByStatus("pendingInstall"), 0)
					local bpBySourceId = target:getBreakpointBySourceLine(fixturePath, 4)
					check.eq(assert(bpBySourceId).id, bp3.id)
					bpBySourceId = target:getBreakpointBySourceLine(fixturePath, 6)
					check.eq(bpBySourceId, nil)
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
		check.eq(targetLaunched, nil)
		-- we expect this breakpoint to be immediately installed
		bpGet = assert(target:getBreakpointById(bp3.id))
		check.eq(bpGet.id, bp3.id)
		check.eq(bpGet.line, 4)
		check.eq(bpGet.sourcePath, normalizePath(fixturePath))
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
	suite:case("stopOnBp", function(check)
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
		check.eq(targetLaunched, nil)
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
	-- this test case focuses on multiple sources
	suite:case("multisource", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/require_main.luau"))
		local triangPath = path.format(path.join(proc.cwd(), "tests/src/debug/require_triang.luau"))
		local bp1 = target:setBreakpoint(mainPath, 5)
		local _bp2 = target:setBreakpoint(triangPath, 5)
		local bpHit1 = 0
		local bpHit2 = 0
		local onFinished = false
		local targetLaunched = target:launch(mainPath, {}, {
			onBreakpointHit = function(_thread, bp)
				if bp.id == bp1.id then
					bpHit1 += 1
				else
					bpHit2 += 1
				end
				local continued = target:continueProcess()
				check.that(continued)
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.eq(targetLaunched, nil)
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		check.eq(bpHit1, 5)
		check.eq(bpHit2, 15)
		local source = target:getLoadedSources()
		check.that(table.find(source, normalizePath(mainPath)))
		check.that(table.find(source, normalizePath(triangPath)))
	end)
	-- this test case focuses on multiple threads
	suite:case("multithread", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/task.luau"))
		local bp1 = target:setBreakpoint(mainPath, 7)
		local _bp2 = target:setBreakpoint(mainPath, 14)
		local bpHit1 = 0
		local bpHit2 = 0
		local onFinished = false
		local maxThreads = 0
		local launchError = target:launch(mainPath, {}, {
			onBreakpointHit = function(thread, bp)
				if bp.id == bp1.id then
					local stoppedThread = assert(target:getStoppedThread())
					check.eq(stoppedThread.id, 2)
					check.eq(thread.id, 2)
					check.eq(thread.name, "Coroutine 2")
					bpHit1 += 1
				else
					local stoppedThread = assert(target:getStoppedThread())
					check.eq(stoppedThread.id, 3)
					check.eq(thread.id, 3)
					check.eq(thread.name, "Coroutine 3")
					bpHit2 += 1
				end
				local threads = target:getThreads()
				maxThreads = math.max(maxThreads, #threads)
				local continued = target:continueProcess()
				check.that(continued)
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.eq(launchError, nil)
		local stoppedThread = assert(target:getMainThread())
		check.eq(stoppedThread.id, 1)
		check.eq(stoppedThread.name, "Main Coroutine")
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		check.eq(bpHit1, 5)
		check.eq(bpHit2, 5)
		check.eq(maxThreads, 3)
	end)
	-- this test case focuses on replacing print
	suite:case("print", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/print.luau"))
		local prints: { { read msg: string, read line: number } } = {}
		local onFinished = false
		local launchError = target:launch(mainPath, {}, {
			onPrint = function(msg, source, line)
				local print = {
					msg = msg,
					line = line,
				}
				table.insert(prints, print)
				check.eq(source, normalizePath(mainPath))
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.eq(launchError, nil)
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
		check.eq(#prints, 2)
		check.eq(prints[1].msg, "3\tabc\tfalse\n")
		check.eq(prints[1].line, 6)
		check.eq(prints[2].msg, "custom_value\n")
		check.eq(prints[2].line, 7)
	end)
	-- this test case focuses on inspecting stack trace
	suite:case("inspectStackTrace", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/pow.luau"))
		target:setBreakpoint(mainPath, 5)
		local hits = 0
		local onFinished = false
		local launchError = target:launch(mainPath, {}, {
			onBreakpointHit = function(thread, bp)
				hits += 1
				local threads = target:getThreads()
				check.eq(#threads, 1)
				local stacktrace = target:getStackTrace(threads[1].id)
				assert(stacktrace)
				check.eq(#stacktrace, hits + 1)
				check.eq(target:getStackDepth(threads[1].id), hits + 1)
				for i, frame in stacktrace do
					check.eq(frame.id, i)
					check.eq(frame.column, 0)
					check.eq(frame.sourcePath, mainPath)
					if i == #stacktrace then
						check.eq(frame.name, "(entry)")
						check.eq(frame.line, 8)
					else
						check.eq(frame.name, "pow")
						check.eq(frame.line, 5)
					end
				end
				-- this a small check that getStackFrame() works
				local specificFrame = target:getStackFrame(threads[1].id, 0)
				assert(specificFrame)
				check.eq(specificFrame.id, 1)
				check.eq(specificFrame.column, 0)
				check.eq(specificFrame.sourcePath, mainPath)
				local continued = target:continueProcess()
				check.that(continued)
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.eq(launchError, nil)
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
	end)
end)
