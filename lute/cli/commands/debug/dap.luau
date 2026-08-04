local dapStream = require("./dapStream")
local dapTypes = require("./dapTypes")
local debugger = require("@lute/debugger")
local json = require("@std/json")

local function createSource(sourcePath: string): dapTypes.Source
	return {
		path = sourcePath,
		name = sourcePath:match("[^/\\]+$"),
	}
end

local function debugToDapBreakpoint(breakpoint: debugger.Breakpoint): dapTypes.Breakpoint
	local dapBreakpoint: dapTypes.Breakpoint = {
		id = breakpoint.id,
		verified = breakpoint.status == "installed",
		source = createSource(breakpoint.sourcePath),
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
	local resultBps = {}
	if requestedBreakpoints then
		for _, setBp in requestedBreakpoints do
			table.insert(resultBps, debugToDapBreakpoint(target:setBreakpoint(sourcePath, setBp.line)))
		end
	end
	return resultBps
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
				source = createSource(source),
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
				local launched = target:launch(launchConfig.program, launchConfig.args, launchCallbacks)
				ioSession.writeResponse(launchSeq, launched, "launch")
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
					-- TODO: better error handling when launching. report the error back to the user.
					local launched = target:launch(launchConfig.program, launchConfig.args, launchCallbacks)
					ioSession.writeResponse(reqSeq, launched, command)
				end
			end
		elseif command == "loadedSources" then
			local sources = target:getLoadedSources()
			local dapSources = {}
			for _, source in sources do
				table.insert(dapSources, createSource(source))
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
		-- dummy handler for stackTrace
		elseif command == "stackTrace" then
			local launchPath = assert(launchConfig, "not launched")
			ioSession.writeResponse(reqSeq, true, command, nil, {
				stackFrames = {
					{
						id = 0,
						name = "main",
						source = createSource(launchPath.program),
						line = target:getLine(),
						column = 0,
					},
				},
				totalFrames = 1,
			})
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
