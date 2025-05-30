export type ProcessRunOptions = {
	shell: string?,
	cwd: string?,

	env: { [string]: string }?,
}

export type ProcessResult = {
	stdout: string,
	stderr: string,

	exitcode: number,
}

local process = {}

function process.homedir(): string
	error("not implemented")
end

function process.cwd(): string
	error("not implemented")
end

function process.run(name: string, args: { string }, options: ProcessRunOptions): ProcessResult
	error("not implemented")
end

return process
