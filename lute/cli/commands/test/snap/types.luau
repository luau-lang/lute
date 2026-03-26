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

return {}
