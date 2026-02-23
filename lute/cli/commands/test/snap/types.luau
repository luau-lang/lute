local path = require("@std/path")

export type snappass = {
	filepath: path.path,
	artifactpath: string,
}

export type snapfail = {
	filepath: path.path,
	artifactpath: string,
	actual: string,
	expected: string,
	diff: string,
	stderr: string?,
}

export type snapnew = {
	filepath: path.path,
	artifactpath: string,
	actual: string,
}

export type snapresult = {
	passed: { snappass },
	failed: { snapfail },
	new: { snapnew },
}

return {}
