-- lute-lint-global-ignore(unused_variable)
local debug = {}

--- The status of a breakpoint, where pendingInstall and pendingUninstall means that the corresponding
--- operation is queued asynchronously
export type BreakpointStatus = "pendingInstall" | "pendingUninstall" | "installed" | "invalid"

--- A breakpoint that stops execution when encountered during runtime
export type Breakpoint = {
	id: number,
	line: number,
	sourcePath: string,
	status: BreakpointStatus,
}

--- A set of callbacks that we configure before launching our debugger
export type LaunchConfig = {
	--- called when a breakpoint `bp` is hit; execution is paused until continueProcess() is called
	onBreakpointHit: ((bp: Breakpoint) -> ())?,
	--- called when breakpoint `bp` is successfully installed in the VM
	onBreakpointInstall: ((bp: Breakpoint) -> ())?,
	--- called when a breakpoint `bp` is uninstalled from the VM
	onBreakpointUninstall: ((bp: Breakpoint) -> ())?,
	--- called when the debugged script exits. `success` reflects if the script exited without errors.
	onExit: ((success: boolean) -> ())?,
}

--- A `Target` represents the target program under the debugger.
--- A `Target` generally handles what is relevant to static code, such as breakpoints.
export type Target = {
	--- Sets a breakpoint at `sourcePath` with a given line and queue it for installation.
	--- If this bp already existed return the preexisting breakpoint. Otherwise, it returns the new one.
	setBreakpoint: (self: Target, sourcePath: string, line: number) -> Breakpoint,
	--- Remove a breakpoint with a given id and queue for uninstall.
	--- Returns whether it was successful or not.
	removeBreakpoint: (self: Target, id: number) -> boolean,
	--- Get all breakpoints belonging to a target.
	getBreakpoints: (self: Target) -> { Breakpoint },
	--- Get all breakpoints belonging to a target with a certain status.
	getBreakpointsByStatus: (self: Target, status: BreakpointStatus) -> { Breakpoint },
	--- Get a breakpoint with a given id.
	getBreakpointById: (self: Target, id: number) -> Breakpoint?,
	--- Get a breakpoint at a `sourcePath` at a given line. Returns nil if not found.
	getBreakpointBySourceLine: (self: Target, sourcePath: string, line: number) -> Breakpoint?,
	--- Launch a Luau script at at `sourcePath` with the relevant `args` and callbacks.
	--- Returns a `Process` handle or nil if the file was unable to be launched.
	launch: (self: Target, sourcePath: string, args: { string }?, config: LaunchConfig?) -> Process?,
	--- Continues a target script if it has been stopped. Return `true` if the target was actually stopped
	--- and `false` if it was not.
	continueProcess: (self: Target) -> boolean,
}

--- Create a new Target handle on the current VM.
function debug.newTarget(): Target
	error("not implemented")
end

return debug
