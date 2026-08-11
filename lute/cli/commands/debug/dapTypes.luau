-- these types reflect our requirements for our implementation of DAP, not
-- necessarily the actual DAP specification. For example, sources in DAP could have
-- path be optional, but we enforce that it is required.

export type Capability = {
	supportConfigurationDoneRequest: boolean,
	supportTerminateRequest: boolean,
	supportsLoadedSourcesRequest: boolean,
	supportsDelayedStackTraceLoading: boolean,
}

export type Source = {
	path: string,
	name: string?,
}

export type SourceBreakpoint = {
	line: number,
}

export type SetBreakpointsArgs = {
	source: Source,
	breakpoints: { SourceBreakpoint },
}

export type Breakpoint = {
	id: number,
	verified: boolean,
	source: Source,
	reason: ("pending" | "failed")?,
	line: number,
}

export type LaunchArgs = {
	program: string,
	args: { string }?,
}

return {}
