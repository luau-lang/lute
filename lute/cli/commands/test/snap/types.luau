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

export type TestConfiguration = {
	--- Arguments to pass `lute` before the snapshot file
	args: { string },
}

export type SnapshotConfiguration = {
	-- The arguments lute expects
	config: TestConfiguration?,
	-- Per test case overrides - in the format
	overrides: { [string]: TestConfiguration? }?,
}

return {}
