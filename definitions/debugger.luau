-- lute-lint-global-ignore(unused_variable)
local debugger = {}

--- The status of a breakpoint, where pendingInstall and pendingUninstall means that the corresponding
--- operation is queued to happen when the script is next paused.
export type BreakpointStatus = "pendingInstall" | "pendingUninstall" | "installed" | "invalid"

--- A breakpoint that stops execution when encountered during runtime
--- if condition is not "", the condition must evaluate to true before stopping.
--- if hitCondition is not "", a condition involving the hitCount must be true before stopping.
--- if logMessage is not "", then instead of stopping we simply output an interpolated log message to the relevant callback.
export type Breakpoint = {
	id: number,
	line: number,
	--- this source path will use forward slashes
	sourcePath: string,
	condition: string,
	hitCondition: string,
	hitCount: number,
	logMessage: string,
	status: BreakpointStatus,
}

--- Info about exception breakpoints and which ids they are using
export type ExceptionBreakpointInfo = {
	uncaughtExceptions: boolean,
	uncaughtId: number,
	caughtExceptions: boolean,
	caughtId: number,
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

--- The type of a VariableScope (i.e. whether it contains local variables, upvalues, or
--- values from a table)
export type VariableScopeType = "locals" | "upvalues" | "table"

--- A VariableScope contains the contextual information for a collection of Variables
--- such as what variable reference ID number to refer to this collection, what type of collection
--- it is, etc. Variable reference IDs are reset upon continuing execution.
export type VariableScope = {
	variableRef: number,
	type: VariableScopeType,
	name: string,
	threadId: number,
	level: number,
}

--- The type of a value in Lua. "void" exists only for
--- evaluateExpressions that do not return anything.
export type LuaValueType =
	"nil"
	| "boolean"
	| "number"
	| "vector"
	| "string"
	| "table"
	| "function"
	| "userdata"
	| "thread"
	| "buffer"
	| "void"

--- A Variable represents an inspected variable from the script, including its name,
--- type, and a value.
--- If the Variable represented is a table, its value may be condensed
--- to a shorter one-line summary. It will then have a variableRef > 0 that can be inspected further.
export type Variable = {
	name: string,
	value: string,
	type: LuaValueType,
	variableRef: number,
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
	--- called when hitting an exception on `thread`. `bpId` reflects the id of the bp hit. These ids
	--- match what is returned by setExceptionBreakpoint. `message` is the message thrown by the exception.
	onException: ((thread: Thread, bpId: number, message: string) -> ())?,
	--- called when we hit a log point `bp` and we are asked to log `message`
	onLogpointHit: ((message: string, bp: Breakpoint) -> ())?,
}

--- A `Target` represents the target program under the debugger.
export type Target = {
	--- Sets a breakpoint at `sourcePath` with a given line and queue it for installation.
	--- If this bp already existed return the preexisting breakpoint. Otherwise, it returns the new one.
	--- Use `config` to add settings for conditional bps, hit condition bps, or logpoints.
	setBreakpoint: (self: Target, sourcePath: string, line: number, config: BreakpointConfig?) -> Breakpoint,
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
	--- Sets/removes whether we hit exception breakpoints for caught or uncaught exceptions based on the
	--- booleans `caught` and `uncaught`. Returns a sumamry of the current exception bp state.
	setExceptionBreakpoint: (self: Target, caught: boolean, uncaught: boolean) -> ExceptionBreakpointInfo,
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
	--- Gets a set of variable scopes on the stack frame with id `frameId`. Return `nil` if script is running
	--- or if that stack frame is not found.
	getScopes: (self: Target, frameId: number) -> { VariableScope }?,
	--- Gets a set of variables belonging to the scope refered by `variableRef`. Return `nil` if script is running
	--- or if such a scope does not exist.
	getVariables: (self: Target, variableRef: number) -> { Variable }?,
	--- Gets a set of variables belonging on the stack frame with id `frameID` with a certain `scopeType`.
	--- `scopeType` should be `locals` or `upvalues`, not `table`.
	--- Return `nil` if script is running or if such variables can not be found.
	getVariablesByScopeType: (self: Target, frameId: number, scopeType: VariableScopeType) -> { Variable }?,
	--- Evaluates an expression within the scope of a given stack frame id.
	--- If `frameId` is absent or -1, evaluate in the global scope.
	--- Returns a `Variable` if expression could be evaluated or an error string if not.
	evaluateExpression: (self: Target, expression: string, frameId: number?) -> Variable | string,
	--- Sets a variable named `name` within the scope with reference `variableRef` equals to the value
	--- that `setExpression` evaluates to. If this operation is not successful, it returns an error string.
	--- Otherwise, it returns a `Variable` containing the new value.
	setVariable: (self: Target, varRef: number, varName: string, setExpression: string) -> Variable | string,
	--- Sets the l-expression that `lExpression` is equal to to the value that `setExpression` evaluates to.
	--- This is done within the scope of the stack frame with `frameID`. If `frameId` is absent or -1,
	--- we are in the global scope. If this operation is not successful, it returns an error string.
	--- Otherwise, it returns a `Variable` containing the new value.
	setExpression: (self: Target, lExpression: string, setExpression: string, frameID: number?) -> Variable | string
}

--- Create a new Target handle on the current VM.
function debugger.newTarget(): Target
	error("not implemented")
end

return debugger
