local process = (require)("@lute/process") -- temporary ()

export type Styler = (text: string) -> string

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
		local index = searchForSubstringIn(str, close, #open + 1)
		local encasedString = if index then replaceClose(str, close, replaceCloseWith, index) else str

		return open .. encasedString .. close
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

local function colorful(colorEnabled: boolean?)
	local f = formatter

	if colorEnabled == nil then
		colorEnabled = process.env.NO_COLOR ~= nil
	end

	if not colorEnabled then
		f = function()
			return function(str: string)
				return str
			end
		end
	end

	return {
		combine = combine,

		reset = f("\x1b[0m", "\x1b[0m"),
		bold = f("\x1b[1m", "\x1b[22m", "\x1b[22m\x1b[1m"),
		dim = f("\x1b[2m", "\x1b[22m", "\x1b[22m\x1b[2m"),
		italic = f("\x1b[3m", "\x1b[23m"),
		underline = f("\x1b[4m", "\x1b[24m"),
		inverse = f("\x1b[7m", "\x1b[27m"),
		hidden = f("\x1b[8m", "\x1b[28m"),
		strikethrough = f("\x1b[9m", "\x1b[29m"),

		black = f("\x1b[30m", "\x1b[39m"),
		red = f("\x1b[31m", "\x1b[39m"),
		green = f("\x1b[32m", "\x1b[39m"),
		yellow = f("\x1b[33m", "\x1b[39m"),
		blue = f("\x1b[34m", "\x1b[39m"),
		magenta = f("\x1b[35m", "\x1b[39m"),
		cyan = f("\x1b[36m", "\x1b[39m"),
		white = f("\x1b[37m", "\x1b[39m"),
		gray = f("\x1b[90m", "\x1b[39m"),

		bgBlack = f("\x1b[40m", "\x1b[49m"),
		bgRed = f("\x1b[41m", "\x1b[49m"),
		bgGreen = f("\x1b[42m", "\x1b[49m"),
		bgYellow = f("\x1b[43m", "\x1b[49m"),
		bgBlue = f("\x1b[44m", "\x1b[49m"),
		bgMagenta = f("\x1b[45m", "\x1b[49m"),
		bgCyan = f("\x1b[46m", "\x1b[49m"),
		bgWhite = f("\x1b[47m", "\x1b[49m"),

		blackBright = f("\x1b[90m", "\x1b[39m"),
		redBright = f("\x1b[91m", "\x1b[39m"),
		greenBright = f("\x1b[92m", "\x1b[39m"),
		yellowBright = f("\x1b[93m", "\x1b[39m"),
		blueBright = f("\x1b[94m", "\x1b[39m"),
		magentaBright = f("\x1b[95m", "\x1b[39m"),
		cyanBright = f("\x1b[96m", "\x1b[39m"),
		whiteBright = f("\x1b[97m", "\x1b[39m"),

		bgBlackBright = f("\x1b[100m", "\x1b[49m"),
		bgRedBright = f("\x1b[101m", "\x1b[49m"),
		bgGreenBright = f("\x1b[102m", "\x1b[49m"),
		bgYellowBright = f("\x1b[103m", "\x1b[49m"),
		bgBlueBright = f("\x1b[104m", "\x1b[49m"),
		bgMagentaBright = f("\x1b[105m", "\x1b[49m"),
		bgCyanBright = f("\x1b[106m", "\x1b[49m"),
		bgWhiteBright = f("\x1b[107m", "\x1b[49m"),
	}
end

return colorful
