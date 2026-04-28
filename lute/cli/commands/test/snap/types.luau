local path = require("@std/path")

export type SnapPass = {
	filepath: path.Path,
	artifactpath: string,
}

export type ProcessExitCondition = {
	expected: number,
	actual: number,
}

export type SnapFail = {
	filepath: path.Path,
	artifactpath: string,
	actual: string,
	expected: string,
	exitCondition: ProcessExitCondition?,
	diff: string,
	stderr: string?,
}

export type SnapNew = {
	filepath: path.Path,
	artifactpath: string,
	actual: string,
}

export type SnapResult = {
	passed: { SnapPass },
	failed: { SnapFail },
	new: { SnapNew },
}

--- Configuration for an individual test
export type TestConfiguration = {
	--- Arguments to pass `lute` before the snapshot file
	args: { string }?,
	--- Expected process exit code - if nil, not checked
	expectedExitCode: number?,
}

--- SnapshotConfiguration format
export type SnapshotConfiguration = {
	--- Default arguments for the directory
	default: TestConfiguration?,
	--- Per test case overrides - each override is just the name of the snapshot (no file extensions)
	overrides: { [string]: TestConfiguration? }?,
}

return {}
