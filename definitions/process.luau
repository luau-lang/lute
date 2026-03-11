-- lute-lint-global-ignore(unused_variable)
export type StdioKind = "default" | "inherit" | "none"

export type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

export type ProcessSystemOptions = {
	system: string?,
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

process.args = {} :: { string }
process.env = {} :: { [string]: string }

function process.homedir(): string
	error("not implemented")
end

function process.cwd(): string
	error("not implemented")
end

function process.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	error("not implemented")
end

function process.system(command: string, options: ProcessSystemOptions?): ProcessResult
	error("not implemented")
end

function process.exit(exitcode: number): never
	error("not implemented")
end

function process.execpath(): string
	error("not implemented")
end

return process
