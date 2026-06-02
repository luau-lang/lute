-- lute-lint-global-ignore(unused_variable)
--- The size of the terminal window.
export type Winsize = {
	rows: number,
	cols: number,
}

--- Options for `tty.open`.
--- - `raw`: put the terminal into raw mode (no line buffering, no signal generation).
export type OpenOptions = {
	raw: boolean?,
}

--- A handle to a TTY file descriptor. Created via `tty.open`.
export type TTY = {
	--- Reads the next chunk of input from the terminal. Yields until input is
	--- available. Returns `nil` once the stream reaches EOF or is closed.
	read: (self: TTY) -> string?,
	--- Writes `bytes` to the terminal. Buffered: returns immediately without
	--- yielding for the write to drain.
	write: (self: TTY, bytes: string) -> (),
	--- Closes the terminal handle. After `close`, `read` returns `nil` and
	--- `write` errors.
	close: (self: TTY) -> (),
	--- Registers `callback` to be invoked whenever the terminal receives
	--- a `SIGWINCH`(window changed) event
	onResize: (self: TTY, callback: (Winsize) -> ()) -> (),
}

local tty = {}

--- Opens a TTY handle for `fd`. Errors if `fd` is not a TTY.
function tty.open(fd: number, opts: OpenOptions?): TTY
	error("not implemented")
end

return tty
