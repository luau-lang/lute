--[[
	richterm
	terminal ansi formatter
]]

export type Formatter = (s: string, nocolor: boolean?) -> string

-- @noinline (if it ever exists)
local function format(s: string, open: string, close: string, replace: string): string
	local index = string.find(s, close, #open + 1, true)
	local middle = s

	if index then
		local closeLen = #close
		local middleTbl = {}
		local cursor = 1

		while index do
			table.insert(middleTbl, string.sub(s, cursor, index - 1))
			cursor = index + closeLen
			index = string.find(s, close, cursor, true)
		end

		middle = table.concat(middleTbl, replace)
	end

	return open .. middle .. close
end

local function formatter(open: string, close: string, replace: string?): Formatter
	replace = replace or open

	return function(s, nocolor)
		return if nocolor then s else format(s, open, close, replace :: string)
	end
end

local richterm = {
	reset = formatter("\x1b[0m", "\x1b[0m"),
	bold = formatter("\x1b[1m", "\x1b[22m", "\x1b[22m\x1b[1m"),
	dim = formatter("\x1b[2m", "\x1b[22m", "\x1b[22m\x1b[2m"),
	italic = formatter("\x1b[3m", "\x1b[23m"),
	underline = formatter("\x1b[4m", "\x1b[24m"),
	inverse = formatter("\x1b[7m", "\x1b[27m"),
	hidden = formatter("\x1b[8m", "\x1b[28m"),
	strikethrough = formatter("\x1b[9m", "\x1b[29m"),

	black = formatter("\x1b[30m", "\x1b[39m"),
	red = formatter("\x1b[31m", "\x1b[39m"),
	green = formatter("\x1b[32m", "\x1b[39m"),
	yellow = formatter("\x1b[33m", "\x1b[39m"),
	blue = formatter("\x1b[34m", "\x1b[39m"),
	magenta = formatter("\x1b[35m", "\x1b[39m"),
	cyan = formatter("\x1b[36m", "\x1b[39m"),
	white = formatter("\x1b[37m", "\x1b[39m"),
	gray = formatter("\x1b[90m", "\x1b[39m"),

	bgBlack = formatter("\x1b[40m", "\x1b[49m"),
	bgRed = formatter("\x1b[41m", "\x1b[49m"),
	bgGreen = formatter("\x1b[42m", "\x1b[49m"),
	bgYellow = formatter("\x1b[43m", "\x1b[49m"),
	bgBlue = formatter("\x1b[44m", "\x1b[49m"),
	bgMagenta = formatter("\x1b[45m", "\x1b[49m"),
	bgCyan = formatter("\x1b[46m", "\x1b[49m"),
	bgWhite = formatter("\x1b[47m", "\x1b[49m"),

	brightBlack = formatter("\x1b[90m", "\x1b[39m"),
	brightRed = formatter("\x1b[91m", "\x1b[39m"),
	brightGreen = formatter("\x1b[92m", "\x1b[39m"),
	brightYellow = formatter("\x1b[93m", "\x1b[39m"),
	brightBlue = formatter("\x1b[94m", "\x1b[39m"),
	brightMagenta = formatter("\x1b[95m", "\x1b[39m"),
	brightCyan = formatter("\x1b[96m", "\x1b[39m"),
	brightWhite = formatter("\x1b[97m", "\x1b[39m"),

	bgBrightBlack = formatter("\x1b[100m", "\x1b[49m"),
	bgBrightRed = formatter("\x1b[101m", "\x1b[49m"),
	bgBrightGreen = formatter("\x1b[102m", "\x1b[49m"),
	bgBrightYellow = formatter("\x1b[103m", "\x1b[49m"),
	bgBrightBlue = formatter("\x1b[104m", "\x1b[49m"),
	bgBrightMagenta = formatter("\x1b[105m", "\x1b[49m"),
	bgBrightCyan = formatter("\x1b[106m", "\x1b[49m"),
	bgBrightWhite = formatter("\x1b[107m", "\x1b[49m"),
}

function richterm.combine(...: Formatter): Formatter
	local formatters = { ... }

	return function(s, nocolor)
		if not nocolor then
			for _, formatter in formatters do
				s = formatter(s)
			end
		end

		return s
	end
end

return table.freeze(richterm)
