-- while these types may have additional fields, we only record
-- the ones the DAP server currently uses.

export type Capabilitiy = {
	supportConfigurationDoneRequest: boolean?,
	supportTerminateRequest: boolean?,
}

export type Source = {
	path: string?,
	name: string?,
}

export type SourceBreakpoint = {
	line: number,
}

export type SetBreakpointsArgs = {
	source: Source,
	breakpoints: { SourceBreakpoint }?,
}

export type Breakpoint = {
	id: number?,
	verified: boolean,
	source: Source?,
	reason: ("pending" | "failed")?,
	line: number?,
}

export type LaunchArgs = {
	program: string,
	args: { string }?,
}

return {}
