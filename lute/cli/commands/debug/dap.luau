local dapStream = require("./dapStream")
local dapTypes = require("./dapTypes")
local debugger = require("@lute/debugger")
local json = require("@std/json")

local function createSource(sourcePath: string): dapTypes.Source?
	if sourcePath == "" or sourcePath == "=[C]" then
		return nil
	end
	return {
		path = sourcePath,
		name = sourcePath:match("[^/\\]+$"),
	}
end

local function debugToDapBreakpoint(breakpoint: debugger.Breakpoint): dapTypes.Breakpoint
	local dapBreakpoint: dapTypes.Breakpoint = {
		id = breakpoint.id,
		verified = breakpoint.status == "installed",
		source = assert(createSource(breakpoint.sourcePath)),
		line = breakpoint.line,
	}
	if breakpoint.status == "pendingInstall" then
		dapBreakpoint.reason = "pending"
	end
	if breakpoint.status == "invalid" then
		dapBreakpoint.reason = "failed"
	end
	return dapBreakpoint
end

local function clearAndSetBreakpoints(
	target: debugger.Target,
	sourcePath: string,
	requestedBreakpoints: { dapTypes.SourceBreakpoint }?
): { dapTypes.Breakpoint }
	local currentBps = target:getBreakpoints()
	for _, bp in currentBps do
		if bp.sourcePath == sourcePath then
			target:removeBreakpoint(bp.id)
		end
	end
	local requestedBps = {}
	if requestedBreakpoints then
		for _, setBp in requestedBreakpoints do
			table.insert(
				requestedBps,
				debugToDapBreakpoint(target:setBreakpoint(sourcePath, setBp.line, {
					condition = setBp.condition,
					hitCondition = setBp.hitCondition,
					logMessage = setBp.logMessage,
				}))
			)
		end
	end
	return requestedBps
end

local function dapLoop(reader: dapStream.Reader, writer: dapStream.Writer)
	local ioSession = dapStream.makeDapStreamSession(reader, writer)
	local target = debugger.newTarget()
	local launchCallbacks: debugger.LaunchConfig = {
		onBreakpointHit = function(thread: debugger.Thread, bp: debugger.Breakpoint)
			ioSession.writeEvent("stopped", {
				reason = "breakpoint",
				threadId = thread.id,
				hitBreakpointIds = { bp.id },
				allThreadsStopped = true,
			})
		end,
		onBreakpointInstall = function(bp: debugger.Breakpoint)
			ioSession.writeEvent("breakpoint", {
				reason = "changed",
				breakpoint = debugToDapBreakpoint(bp),
			})
		end,
		onExit = function(success: boolean)
			local exitCode = if success then 0 else 1
			ioSession.writeEvent("exited", {
				exitCode = exitCode,
			})
			ioSession.writeEvent("terminated")
		end,
		-- we need to give a thread ID upon pausing for VSCode UI
		onPause = function(thread: debugger.Thread)
			ioSession.writeEvent("stopped", {
				reason = "pause",
				threadId = thread.id,
				allThreadsStopped = true,
			})
		end,
		onPrint = function(message: string, source: string, line: number)
			ioSession.writeEvent("output", {
				category = "stdout",
				output = message,
				source = assert(createSource(source)),
				line = line,
			})
		end,
		onStepStop = function(thread: debugger.Thread, _stepInfo: debugger.StepInfo)
			ioSession.writeEvent("stopped", {
				reason = "step",
				threadId = thread.id,
				allThreadsStopped = true,
			})
		end,
		onLogpointHit = function(message: string, breakpoint: debugger.Breakpoint)
			ioSession.writeEvent("output", {
				category = "stdout",
				output = message,
				source = createSource(breakpoint.sourcePath),
				line = breakpoint.line,
			})
		end,
		onException = function(thread: debugger.Thread, bpId: number, message: string)
			ioSession.writeEvent("stopped", {
				reason = "exception",
				threadId = thread.id,
				allThreadsStopped = true,
				text = message,
				hitBreakpointIds = { bpId },
			})
		end,
	}
	local configurationDone = false
	local launchConfig: dapTypes.LaunchArgs? = nil
	local launchSeq = -1
	while true do
		local request = ioSession.readDap()
		local command = request.command :: string
		local reqSeq = request.seq :: number
		if command == "initialize" then
			local capabilities = {
				supportsConfigurationDoneRequest = true,
				supportsTerminateRequest = true,
				supportsLoadedSourcesRequest = true,
				supportsDelayedStackTraceLoading = true,
				supportsVariableType = true,
				supportsEvaluateForHovers = true,
				supportsConditionalBreakpoints = true,
				supportsHitConditionalBreakpoints = true,
				supportsLogPoints = true,
				exceptionBreakpointFilters = {
					{
						filter = "uncaught",
						label = "Uncaught Exceptions",
						description = "Stop debugger at all points where an uncaught exception is thrown",
						default = true,
					},
					{
						filter = "caught",
						label = "Caught Exceptions",
						description = "Stop debugger at all points where a caught exception is thrown in a pcall()/xpcall()",
						default = false,
					},
				},
			}
			ioSession.writeResponse(reqSeq, true, command, nil, capabilities)
			ioSession.writeEvent("initialized")
		elseif command == "configurationDone" then
			configurationDone = true
			-- clients can send either configurationDone before or after launch.
			-- in the second case, we delay sending a response to the launch request until after
			-- configuration is done.
			ioSession.writeResponse(reqSeq, true, command)
			if launchConfig then
				local error = target:launch(launchConfig.program, launchConfig.args, launchCallbacks)
				if error then
					ioSession.writeResponse(launchSeq, false, "launch", error)
				else
					ioSession.writeResponse(launchSeq, true, "launch")
				end
			end
		elseif command == "setBreakpoints" then
			local args = request.arguments :: json.Object
			local source = args.source :: dapTypes.Source
			local path = source.path :: string
			local newBreakpoints = args.breakpoints :: { dapTypes.SourceBreakpoint }?
			local requestedBreakpoints = clearAndSetBreakpoints(target, path, newBreakpoints)

			ioSession.writeResponse(reqSeq, true, command, nil, {
				breakpoints = requestedBreakpoints,
			})
		elseif command == "setExceptionBreakpoints" then
			local args = request.arguments :: json.Object
			local filters = args.filters :: { string }
			local uncaught = false
			local caught = false
			for _, filter in filters do
				if filter == "uncaught" then
					uncaught = true
				end
				if filter == "caught" then
					caught = true
				end
			end
			local exceptionInfo = target:setExceptionBreakpoint(caught, uncaught)
			local requestedBreakpoints: { dapTypes.Breakpoint } = {}
			for _, filter in filters do
				if filter == "uncaught" then
					table.insert(requestedBreakpoints, {
						id = exceptionInfo.uncaughtId,
						verified = true,
					})
				end
				if filter == "caught" then
					table.insert(requestedBreakpoints, {
						id = exceptionInfo.caughtId,
						verified = true,
					})
				end
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				breakpoints = requestedBreakpoints,
			})
		elseif command == "continue" then
			local continued = target:continueProcess()
			ioSession.writeResponse(reqSeq, continued, command)
		elseif command == "pause" then
			local paused = target:pauseProcess()
			ioSession.writeResponse(reqSeq, paused, command)
		elseif command == "launch" then
			local args = request.arguments :: dapTypes.LaunchArgs?
			if args and args.program then
				launchConfig = {
					program = args.program,
					args = args.args,
				}
				launchSeq = reqSeq
				-- configuration is already done, respond to launch
				if configurationDone then
					local error = target:launch(launchConfig.program, launchConfig.args, launchCallbacks)
					if error then
						ioSession.writeResponse(reqSeq, false, command, error)
					else
						ioSession.writeResponse(reqSeq, true, command)
					end
				end
			end
		elseif command == "loadedSources" then
			local sources = target:getLoadedSources()
			local dapSources = {}
			for _, source in sources do
				table.insert(dapSources, assert(createSource(source)))
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				sources = dapSources,
			})
		elseif command == "next" then
			local args = request.arguments :: json.Object
			local threadId = args.threadId :: number
			local stepped = target:stepOver(threadId)
			ioSession.writeResponse(reqSeq, stepped, command)
		elseif command == "stepIn" then
			local args = request.arguments :: json.Object
			local threadId = args.threadId :: number
			local stepped = target:stepIn(threadId)
			ioSession.writeResponse(reqSeq, stepped, command)
		elseif command == "stepOut" then
			local args = request.arguments :: json.Object
			local threadId = args.threadId :: number
			local stepped = target:stepOut(threadId)
			ioSession.writeResponse(reqSeq, stepped, command)
		elseif command == "threads" then
			local threads = target:getThreads()
			local dapThreads = {}
			for _, thread in threads do
				table.insert(dapThreads, {
					id = thread.id,
					name = thread.name,
				})
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				threads = dapThreads,
			})
		elseif command == "stackTrace" then
			local args = request.arguments :: json.Object
			local threadId = args.threadId :: number
			local startFrame = args.startFrame :: number?
			local levels = args.levels :: number?
			local stackTrace = target:getStackTrace(threadId, startFrame, levels)
			if not stackTrace then
				ioSession.writeResponse(reqSeq, false, command, "notStopped")
				continue
			end
			assert(stackTrace)
			local dapStackTrace = {}
			for _, frame in stackTrace do
				table.insert(dapStackTrace, {
					id = frame.id,
					name = frame.name,
					source = createSource(frame.sourcePath),
					line = frame.line,
					column = frame.column,
				})
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				stackFrames = dapStackTrace,
				totalFrames = target:getStackDepth(threadId),
			})
		elseif command == "scopes" then
			local args = request.arguments :: json.Object
			local frameId = args.frameId :: number
			local scopes = target:getScopes(frameId)
			if not scopes then
				ioSession.writeResponse(reqSeq, false, command)
				continue
			end
			assert(scopes)
			local dapScope = {}
			for _, scope in scopes do
				local dapScopeItem = {
					name = scope.name,
					variablesReference = scope.variableRef,
				}
				if scope.type == "locals" then
					dapScopeItem.presentationHint = "locals"
				end
				table.insert(dapScope, dapScopeItem)
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				scopes = dapScope,
			})
		elseif command == "variables" then
			local args = request.arguments :: json.Object
			local varRef = args.variablesReference :: number
			local vars = target:getVariables(varRef)
			if not vars then
				ioSession.writeResponse(reqSeq, false, command)
				continue
			end
			assert(vars)
			local dapVars = {}
			for _, var in vars do
				local dapVarItem = {
					name = var.name,
					type = var.type,
					value = var.value,
					variablesReference = var.variableRef,
				}
				table.insert(dapVars, dapVarItem)
			end
			ioSession.writeResponse(reqSeq, true, command, nil, {
				variables = dapVars,
			})
		elseif command == "evaluate" then
			local args = request.arguments :: json.Object
			local expression = args.expression :: string
			local frameId = args.frameId :: number?
			local result = target:evaluateExpression(expression, frameId)
			if type(result) == "string" then
				ioSession.writeResponse(reqSeq, false, command, result)
			else
				local variable = result :: debugger.Variable
				ioSession.writeResponse(reqSeq, true, command, nil, {
					result = variable.value,
					type = variable.type,
					variablesReference = variable.variableRef,
				})
			end
		elseif command == "terminate" or command == "disconnect" then
			ioSession.writeResponse(reqSeq, true, command)
			ioSession.writeEvent("terminated")
			break
		else
			ioSession.writeResponse(reqSeq, false, command, `unsupported command: {command}`)
		end
	end
end

return {
	dapLoop = dapLoop,
}
