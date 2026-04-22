local path = require("@std/path")

export type snappass = {
	filepath: path.Path,
	artifactpath: string,
}

export type snapfail = {
	filepath: path.Path,
	artifactpath: string,
	actual: string,
	expected: string,
	diff: string,
	stderr: string?,
}

export type snapnew = {
	filepath: path.Path,
	artifactpath: string,
	actual: string,
}

export type snapresult = {
	passed: { snappass },
	failed: { snapfail },
	new: { snapnew },
}

--- Configuration for an individual test
export type TestConfiguration = {
	--- Arguments to pass `lute` before the snapshot file
	args: { string },
}

--- SnapshotConfiguration format
export type SnapshotConfiguration = {
	--- Default arguments for the directory
	config: TestConfiguration?,
	--- Per test case overrides - each override is just the name of the snapshot (no file extensions)
	overrides: { [string]: TestConfiguration? }?,
}

return {}
