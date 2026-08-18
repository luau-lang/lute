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

local function checkScope(
	check: any,
	scopes: { debug.VariableScope },
	name: string,
	scopeType: debug.VariableScopeType,
	threadId: number,
	level: number
)
	local found = nil
	for _, scope in scopes do
		if scope.name == name then
			found = scope
			break
		end
	end
	check.that(found ~= nil)
	if found then
		check.eq(found.type, scopeType)
		check.eq(found.threadId, threadId)
		check.eq(found.level, level)
		check.that(found.variableRef > 0)
	end
end

local function checkVariable(
	check: any,
	vars: { debug.Variable },
	name: string,
	value: string,
	varType: string,
	isTable: boolean
): number
	local found = nil
	for _, var in vars do
		if var.name == name then
			found = var
			break
		end
	end
	check.that(found ~= nil)
	if found then
		check.eq(found.value, value)
		check.eq(found.type, varType)
		if isTable then
			check.that(found.variableRef > 0)
		else
			check.eq(found.variableRef, 0)
		end
		return found.variableRef
	end
	return 0
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
		local bp2 = target:setBreakpoint(mainPath, 14)
		local _bp3 = target:setBreakpoint(mainPath, 22)
		local bpHit1 = 0
		local bpHit2 = 0
		local onFinished = false
		local maxThreads = 0
		local launchError = target:launch(mainPath, {}, {
			onBreakpointHit = function(thread, bp)
				print(bp.id, bpHit1, bpHit2)
				if bp.id == bp1.id then
					check.eq(thread.id, 2)
					local stoppedThread = assert(target:getStoppedThread())
					check.eq(stoppedThread.id, 2)
					bpHit1 += 1
					local threads = target:getThreads()
					maxThreads = math.max(maxThreads, #threads)
					if #threads == 3 then
						local nameById = {}
						for _, t in threads do
							nameById[t.id] = t.name
						end
						check.eq(nameById[1], "Main Coroutine")
						check.eq(nameById[2], "Coroutine 2")
						check.eq(nameById[3], "Coroutine 3")
					end
					local stackTrace = assert(target:getStackTrace(thread.id))
					local threadStack = stackTrace[#stackTrace]
					check.eq(threadStack.line, 7)
					local vars = assert(target:getVariablesByScopeType(threadStack.id, "local"))
					checkVariable(check, vars, "_i", tostring(bpHit1), "number", false)
					for _, otherThread in threads do
						if otherThread.id == 3 then
							local otherTrace = assert(target:getStackTrace(otherThread.id))
							local line = otherTrace[#otherTrace].line
							check.that(line >= 20 and line <= 15)
						end
						if otherThread.id == 1 then
							local otherTrace = assert(target:getStackTrace(otherThread.id))
							local line = otherTrace[#otherTrace].line
							check.that(line >= 18 and line <= 20)
						end
					end
				elseif bp.id == bp2.id then
					check.eq(thread.id, 3)
					local stoppedThread = assert(target:getStoppedThread())
					check.eq(stoppedThread.id, 3)
					local stackTrace = assert(target:getStackTrace(thread.id))
					local threadStack = stackTrace[#stackTrace]
					check.eq(threadStack.line, 14)
					local threads = target:getThreads()
					for _, otherThread in threads do
						if otherThread.id == 2 then
							local otherTrace = assert(target:getStackTrace(otherThread.id))
							local line = otherTrace[#otherTrace].line
							check.that(line >= 5 and line <= 8)
						end
						if otherThread.id == 1 then
							local otherTrace = assert(target:getStackTrace(otherThread.id))
							local line = otherTrace[#otherTrace].line
							check.that(line >= 18 and line <= 20)
						end
					end
					bpHit2 += 1
					local vars = assert(target:getVariablesByScopeType(threadStack.id, "local"))
					checkVariable(check, vars, "_i", tostring(bpHit2), "number", false)
				else
					local stoppedThread = assert(target:getStoppedThread())
					check.eq(stoppedThread.id, 1)
					local threads = target:getThreads()
					check.eq(thread.id, 1)
					check.eq(#threads, 1)
					check.eq(threads[1].id, 1)
					check.eq(threads[1].name, "Main Coroutine")
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
	-- this test case focuses on stepping
	suite:case("step", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/step.luau"))
		target:setBreakpoint(mainPath, 9)
		local bpHit = false
		local stepsDone = 0
		local onFinished = false
		local error = target:launch(mainPath, {}, {
			onStepStop = function(thread, _info)
				check.eq(thread.id, 1)
				stepsDone += 1
			end,
			onBreakpointHit = function(_thread, _bp)
				bpHit = true
			end,
			onExit = function(status)
				if status then
					onFinished = true
				end
			end,
		})
		check.that(error == nil)
		check.eq(
			waitUntil(function()
				return bpHit
			end),
			true
		)
		local threads = target:getThreads()
		local threadId = threads[1].id
		local source, line = target:getStoppedLocation()
		assert(line)
		assert(source)
		check.eq(source, normalizePath(mainPath))
		check.eq(line, 9)
		target:step(threadId, "stepIn")
		check.eq(
			waitUntil(function()
				return stepsDone == 1
			end),
			true
		)
		source, line = target:getStoppedLocation()
		assert(line)
		assert(source)
		check.eq(source, normalizePath(mainPath))
		check.eq(line, 10)
		target:stepIn(threadId)
		check.eq(
			waitUntil(function()
				return stepsDone == 2
			end),
			true
		)
		source, line = target:getStoppedLocation()
		assert(line)
		assert(source)
		check.eq(source, normalizePath(mainPath))
		check.eq(line, 2)
		target:stepOut(threadId)
		check.eq(
			waitUntil(function()
				return stepsDone == 3
			end),
			true
		)
		source, line = target:getStoppedLocation()
		assert(line)
		assert(source)
		check.eq(source, normalizePath(mainPath))
		check.eq(line, 11)
		target:stepOver(threadId)
		check.eq(
			waitUntil(function()
				return stepsDone == 4
			end),
			true
		)
		source, line = target:getStoppedLocation()
		assert(line)
		assert(source)
		check.eq(source, normalizePath(mainPath))
		check.eq(line, 12)
		target:continueProcess()
		check.eq(
			waitUntil(function()
				return onFinished
			end),
			true
		)
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
			onBreakpointHit = function(_thread, _bp)
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
					check.eq(frame.sourcePath, normalizePath(mainPath))
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
				check.eq(specificFrame.sourcePath, normalizePath(mainPath))
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
	-- this test case focuses on inspecting variables
	suite:case("inspectVariables", function(check)
		local target = debug.newTarget()
		check.eq(typeof(target), "Target")
		local mainPath = path.format(path.join(proc.cwd(), "tests/src/debug/variables.luau"))
		target:setBreakpoint(mainPath, 16)
		local onFinished = false
		local targetLaunched = target:launch(mainPath, {}, {
			onBreakpointHit = function(_thread, _bp)
				local threads = target:getThreads()
				check.eq(#threads, 1)
				local stacktrace = target:getStackTrace(threads[1].id)
				assert(stacktrace)
				check.eq(#stacktrace, 2)
				local scopes = target:getScopes(stacktrace[1].id)
				assert(scopes)
				check.eq(#scopes, 3)
				checkScope(check, scopes, "Locals", "local", threads[1].id, 0)
				checkScope(check, scopes, "Upvalues", "upvalue", threads[1].id, 0)
				checkScope(check, scopes, "Globals", "global", -1, -1)
				for _, scope in scopes do
					if scope.type == "local" then
						local locals = target:getVariables(scope.variableRef)
						assert(locals)
						check.eq(#locals, 1)
						checkVariable(check, locals, "_k", "25.2", "number", false)
					end
					if scope.type == "upvalue" then
						local upvalues = target:getVariables(scope.variableRef)
						assert(upvalues)
						check.eq(#upvalues, 2)
						checkVariable(check, upvalues, "a", "24", "number", false)
						checkVariable(check, upvalues, "_b", "1.2", "number", false)
					end
					if scope.type == "global" then
						local globals = target:getVariables(scope.variableRef)
						assert(globals)
						check.eq(#globals, 1)
						checkVariable(check, globals, "_global_var", "16", "number", false)
					end
				end
				local locals = target:getVariablesByScopeType(stacktrace[2].id, "local")
				assert(locals)
				check.eq(#locals, 12)
				checkVariable(check, locals, "a", "24", "number", false)
				checkVariable(check, locals, "_b", "1.2", "number", false)
				checkVariable(check, locals, "_c", '"test"', "string", false)
				local ref1 = checkVariable(check, locals, "_d", "{1, 2, 3}", "table", true)
				checkVariable(check, locals, "_e", '{a=4, [4]={r=13}, b="5"}', "table", true)
				checkVariable(check, locals, "_f", "true", "boolean", false)
				checkVariable(check, locals, "g", "function", "function", false)
				checkVariable(check, locals, "_largeinteger", "123456789101112", "number", false)
				checkVariable(check, locals, "_smallnumber", "1.2e-14", "number", false)
				checkVariable(check, locals, "_largenumber", "3.53e+106", "number", false)
				checkVariable(check, locals, "_escapechar", '"\\n\\\\\\r\\t\\""', "string", false)
				checkVariable(check, locals, "_precise", "1.234567891011", "number", false)
				local tables = target:getVariables(ref1)
				assert(tables)
				check.eq(#tables, 3)
				checkVariable(check, tables, "[1]", "1", "number", false)
				checkVariable(check, tables, "[2]", "2", "number", false)
				checkVariable(check, tables, "[3]", "3", "number", false)
				local globals = target:getVariablesByScopeType(stacktrace[2].id, "global")
				assert(globals)
				check.eq(#globals, 1)
				checkVariable(check, globals, "_global_var", "16", "number", false)
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
	end)
end)
