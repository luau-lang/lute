-- lute-lint-global-ignore(unused_variable)
local debugger = {}

--- The status of a breakpoint, where pendingInstall and pendingUninstall means that the corresponding
--- operation is queued to happen when the script is next paused.
export type BreakpointStatus = "pendingInstall" | "pendingUninstall" | "installed" | "invalid"

--- A breakpoint that stops execution when encountered during runtime
export type Breakpoint = {
	id: number,
	line: number,
	--- this source path will use forward slashes
	sourcePath: string,
	status: BreakpointStatus,
}

--- The type of step we are taking
export type StepType = "stepIn" | "stepOut" | "stepOver"

--- Information about the current step() command we are running
export type StepInfo = {
	type: StepType,
	startLine: number,
	startDepth: number,
}

--- A thread of execution, which represents one coroutine running on the runtime
export type Thread = {
	id: number,
	name: string,
}

--- A stack frame of the execution. New stack frames are recreated every time execution is paused, and
--- ids are reused.
export type StackFrame = {
	id: number,
	name: string,
	sourcePath: string,
	line: number,
	column: number,
}

--- A set of callbacks that we configure before launching our debugger
export type LaunchConfig = {
	--- called when a breakpoint `bp` is hit on `thread`; execution is paused until continueProcess() is called
	onBreakpointHit: ((thread: Thread, bp: Breakpoint) -> ())?,
	--- called when there is has been an attempt to install the breakpoint `bp` on the VM, regardless
	--- of success and failure. check the status of `bp` to see if the attempt has succeeded or failed.
	onBreakpointInstall: ((bp: Breakpoint) -> ())?,
	--- called when a breakpoint `bp` is uninstalled from the VM
	onBreakpointUninstall: ((bp: Breakpoint) -> ())?,
	--- called when the debugged script exits. `success` reflects if the script exited without errors.
	onExit: ((success: boolean) -> ())?,
	--- called when a pauseProcess() interrupts `thread` and then actually stops all threads from execution.
	onPause: ((thread: Thread) -> ())?,
	--- called when print() would have printed out `message` and is called from `source` on line number `line`
	onPrint: ((message: string, source: string, line: number) -> ())?,
	--- called when our script finishes stepping on `thread`. `info` reflects the information about our stepping command.
	onStepStop: ((thread: Thread, info: StepInfo) -> ())?,
}

--- A `Target` represents the target program under the debugger.
export type Target = {
	--- Sets a breakpoint at `sourcePath` with a given line and queue it for installation.
	--- If this bp already existed return the preexisting breakpoint. Otherwise, it returns the new one.
	setBreakpoint: (self: Target, sourcePath: string, line: number) -> Breakpoint,
	--- Remove a breakpoint with a given `id` and queue for uninstall.
	--- Returns whether it was successful or not.
	removeBreakpoint: (self: Target, id: number) -> boolean,
	--- Get all breakpoints belonging to a target.
	getBreakpoints: (self: Target) -> { Breakpoint },
	--- Get all breakpoints belonging to a target with a certain status.
	getBreakpointsByStatus: (self: Target, status: BreakpointStatus) -> { Breakpoint },
	--- Get a breakpoint with a given id. Returns `nil` if not found.
	getBreakpointById: (self: Target, id: number) -> Breakpoint?,
	--- Get a breakpoint at a `sourcePath` at a given line. Returns `nil` if not found.
	getBreakpointBySourceLine: (self: Target, sourcePath: string, line: number) -> Breakpoint?,
	--- Gets all Luau sources that have been loaded onto the debugger, with sources using forward slashes.
	getLoadedSources: (self: Target) -> { string },
	--- Launch a Luau script at at `sourcePath` with the relevant `args` and callbacks defined in `config`.
	--- Returns nil if launch is successful and an error string otherwise.
	launch: (self: Target, sourcePath: string, args: { string }?, config: LaunchConfig?) -> string?,
	--- Continues a target script if it has been stopped. Return `true` if the target was actually stopped
	--- and `false` if it was not.
	continueProcess: (self: Target) -> boolean,
	--- Pauses a target script if it is running. Return `true` if the target was successfully paused
	--- and `false` if it was not.
	pauseProcess: (self: Target) -> boolean,
	--- Steps in the code at a certain thread with id `threadId`, utilizing a certain step type `type`.
	--- Returns `true` if target was paused before stepping and `false` otherwise.
	step: (self: Target, threadId: number, type: StepType) -> boolean,
	--- Steps into the next line of the code in thread id `threadId`, including into a function if the line contains a function.
	--- Returns `true` if target was paused before stepping and `false` otherwise.
	stepIn: (self: Target, threadId: number) -> boolean,
	--- Steps over to the next line of the code in thread id `threadId`, skipping over any function calls if our current line contains a function.
	--- Returns `true` if target was paused before stepping and `false` otherwise.
	stepOver: (self: Target, threadId: number) -> boolean,
	--- Steps out of the current function call in thread id `threadId`.
	--- Returns `true` if target was paused before stepping and `false` otherwise.
	stepOut: (self: Target, threadId: number) -> boolean,
	--- Gets our current stopped location, consisting of (sourcePath: string, line: number)
	--- Returns (nil, nil) if we are not stopped.
	getStoppedLocation: (self: Target) -> (string?, number?),
	--- Gets a list of all Luau coroutines that are being used by the script.
	getThreads: (self: Target) -> { Thread },
	--- Gets the main thread of the script, returning nil if debugger is not launched
	getMainThread: (self: Target) -> Thread?,
	--- Gets the current stopped thread of the script, returning nil if debugger is not paused
	getStoppedThread: (self: Target) -> Thread?,
	--- Gets the depth of the call stack within thread with `threadId`. If not paused or not launched or if
	--- such a thread does not exist, return `-1`.
	getStackDepth: (self: Target, threadId: number) -> number,
	--- Gets a stack frame on a coroutine with `threadId` at level `level` (where 0 is the shallowest). Return `nil`
	--- if script is running or no such stack frame exists at that level.
	getStackFrame: (self: Target, threadId: number, level: number) -> StackFrame?,
	--- Gets a stack trace on a coroutine with `threadId` starting from level `startLevel` and going for at maximum
	--- `numFrames` frames. If `startLevel` is not specified, we start at level 0. If `numFrames` is not specified,
	--- we return until the deepest frame.
	getStackTrace: (self: Target, threadId: number, startLevel: number?, numFrames: number?) -> { StackFrame }?,
}

--- Create a new Target handle on the current VM.
function debugger.newTarget(): Target
	error("not implemented")
end

return debugger
