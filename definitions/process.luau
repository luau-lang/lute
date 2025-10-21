local pathtypes = require("@std/path/types")

export type StdioKind = "default" | "inherit" | "none" | ""

export type ProcessRunOptions = {
	shell: (string | boolean)?,
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

export type ProcessResult = {
	stdout: string,
	stderr: string,

	ok: boolean,
	exitcode: number,
	signal: string?,
}

local process = {}

process.env = {} :: { [string]: string }

function process.homedir(): pathtypes.path
	error("not implemented")
end

function process.cwd(): pathtypes.path
	error("not implemented")
end

function process.run(args: string | { string }, options: ProcessRunOptions?): ProcessResult
	error("not implemented")
end

function process.exit(exitcode: number): never
	error("not implemented")
end

function process.execpath(): pathtypes.path
	error("not implemented")
end

return process
