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

--- A thread of execution, which represents one coroutine running on the runtime
export type Thread = {
	id: number,
	name: string,
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
	--- Launch a Luau script at at `sourcePath` with the relevant `args` and callbacks.
	--- Returns whether the script could be launched.
	launch: (self: Target, sourcePath: string, args: { string }?, config: LaunchConfig?) -> boolean,
	--- Continues a target script if it has been stopped. Return `true` if the target was actually stopped
	--- and `false` if it was not.
	continueProcess: (self: Target) -> boolean,
	--- Pauses a target script if it is running. Return `true` if the target was successfully paused
	--- and `false` if it was not.
	pauseProcess: (self: Target) -> boolean,
	--- Gets a list of all Luau coroutines that are being used by the script.
	getThreads: (self: Target) -> { Thread },
}

--- Create a new Target handle on the current VM.
function debugger.newTarget(): Target
	error("not implemented")
end

return debugger
