-- lute-lint-global-ignore(unused_variable)
--- How a child process's standard streams should be handled:
--- - `"default"`: Capture stdout and stderr to pipes, accessible via `ProcessResult`.
--- - `"inherit"`: Pass the parent process's stdio streams through to the child.
--- - `"none"`: Discard the child's stdio streams.
export type StdioKind = "default" | "inherit" | "none"

--- Options for `process.run`:
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

--- Options for `process.system`:
--- - `system`: The shell executable to use. If omitted, uses the platform default (`$SHELL` on Unix, `%COMSPEC%` on Windows).
--- - `cwd`: The working directory for the child process. Defaults to the current working directory.
--- - `stdio`: How to handle the child's stdio streams. Defaults to `"default"`.
--- - `env`: Environment variables for the child process. If omitted, inherits the parent's environment.
export type ProcessSystemOptions = {
	system: string?,
	cwd: string?,
	stdio: StdioKind?,

	env: { [string]: string }?,
}

--- The result of a completed process, including exit code and captured stdout/stderr.
export type ProcessResult = {
	stdout: string,
	stderr: string,

	ok: boolean,
	exitcode: number,
	signal: string?,
}

local process = {}

--- Command-line arguments passed to the current script, as an array of strings.
process.args = {} :: { string }
--- A table of environment variables for the current process.
process.env = {} :: { [string]: string }

--- Returns the current user's home directory as a string.
function process.homedir(): string
	error("not implemented")
end

--- Returns the current working directory as a string.
function process.cwd(): string
	error("not implemented")
end

--- Runs the program given by `args[1]` with the remaining entries as arguments. Returns the process result including exit code and any captured output.
function process.run(args: { string }, options: ProcessRunOptions?): ProcessResult
	error("not implemented")
end

--- Runs `command` through the system shell. Returns the process result.
function process.system(command: string, options: ProcessSystemOptions?): ProcessResult
	error("not implemented")
end

--- Exits the current process with the given `exitcode`.
function process.exit(exitcode: number): never
	error("not implemented")
end

--- Returns the path of the currently running lute executable as a string.
function process.execPath(): string
	error("not implemented")
end

return process
