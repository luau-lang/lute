-- these types reflect our requirements for our implementation of DAP, not
-- necessarily the actual DAP specification. For example, sources in DAP could have
-- path be optional, but we enforce that it is required.

export type exceptionBreakpointFilter = {
	filter: string,
	label: string,
	description: string,
	default: boolean,
}

export type Capability = {
	supportConfigurationDoneRequest: boolean,
	supportTerminateRequest: boolean,
	supportsLoadedSourcesRequest: boolean,
	supportsDelayedStackTraceLoading: boolean,
	supportsVariableType: boolean,
	exceptionBreakpointFilters: { exceptionBreakpointFilter },
	supportsEvaluateForHovers: boolean,
	supportsConditionalBreakpoints: boolean,
	supportsHitConditionalBreakpoints: boolean,
	supportsLogPoints: boolean,
	supportsSetVariable: boolean,
}

export type Source = {
	path: string,
	name: string?,
}

export type SourceBreakpoint = {
	line: number,
	condition: string?,
	hitCondition: string?,
	logMessage: string?,
}

export type SetBreakpointsArgs = {
	source: Source,
	breakpoints: { SourceBreakpoint },
}

export type Breakpoint = {
	id: number,
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
