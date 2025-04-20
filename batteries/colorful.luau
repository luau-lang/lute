local process = (require)("@lute/process") -- temporary ()

export type Styler = (text: string) -> string

-- https://no-color.org/
local function colorDisabled(): boolean
	-- is it really okay to index env every style call?
	return process.env.NO_COLOR ~= nil
end

local function searchForSubstringIn(str: string, substring: string, index: number)
	-- last argument of string.find() turns string.find into plain substring search
	return string.find(str, substring, index, true)
end

local function replaceClose(str: string, close: string, replace: string, index: number?): string
	local result = ""
	local cursor = 1

	while index do
		result ..= string.sub(str, cursor, index - 1) .. replace

		cursor = index + #close

		index = searchForSubstringIn(str, close, cursor)
	end

	return result .. string.sub(str, cursor)
end

local function formatter(open: string, close: string, replace: string?): Styler
	local replaceCloseWith = replace or open

	local function created_formatter(str: string): string
		if colorDisabled() then
			return str
		end

		local index = searchForSubstringIn(str, close, #open + 1)
		local encasedString = if index then replaceClose(str, close, replaceCloseWith, index) else str

		return `{open}{encasedString}{close}`
	end

	return created_formatter
end

local function combine(...: Styler): Styler
	local stylers = { ... }

	local function combinedStyler(str: string): string
		local result = str

		for _, styler in stylers do
			result = styler(result)
		end

		return result
	end

	return combinedStyler
end

return {
	combine = combine,

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

	blackBright = formatter("\x1b[90m", "\x1b[39m"),
	redBright = formatter("\x1b[91m", "\x1b[39m"),
	greenBright = formatter("\x1b[92m", "\x1b[39m"),
	yellowBright = formatter("\x1b[93m", "\x1b[39m"),
	blueBright = formatter("\x1b[94m", "\x1b[39m"),
	magentaBright = formatter("\x1b[95m", "\x1b[39m"),
	cyanBright = formatter("\x1b[96m", "\x1b[39m"),
	whiteBright = formatter("\x1b[97m", "\x1b[39m"),

	bgBlackBright = formatter("\x1b[100m", "\x1b[49m"),
	bgRedBright = formatter("\x1b[101m", "\x1b[49m"),
	bgGreenBright = formatter("\x1b[102m", "\x1b[49m"),
	bgYellowBright = formatter("\x1b[103m", "\x1b[49m"),
	bgBlueBright = formatter("\x1b[104m", "\x1b[49m"),
	bgMagentaBright = formatter("\x1b[105m", "\x1b[49m"),
	bgCyanBright = formatter("\x1b[106m", "\x1b[49m"),
	bgWhiteBright = formatter("\x1b[107m", "\x1b[49m"),
}
