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

function process.homedir(): string
	error("not implemented")
end

function process.cwd(): string
	error("not implemented")
end

function process.run(args: string | { string }, options: ProcessRunOptions?): ProcessResult
	error("not implemented")
end

return process
