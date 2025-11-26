local style = {}

-- ANSI Escape Codes
local ESC = "\27"
local CSI = ESC .. "["
local RESET = CSI .. "0m"

type Color = "31" | "32" | "33" | "34" | "35" | "36" | "37" | "90"

local Color = {
	red = "31" :: "31",
	green = "32" :: "32",
	yellow = "33" :: "33",
	blue = "34" :: "34",
	magenta = "35" :: "35",
	cyan = "36" :: "36",
	white = "37" :: "37",
	grey = "90" :: "90",
}

style.colors = Color
function style.color(color: Color, toColor: string): string
	return CSI .. color .. "m" .. toColor .. RESET
end

-- Expose ansi reset in case users want to manually style
style.reset = RESET

function style.bold(text: string): string
	return CSI .. "1m" .. text .. RESET
end

function style.underline(text: string): string
	return CSI .. "4m" .. text .. RESET
end

function style.strikethrough(text: string): string
	return CSI .. "9m" .. text .. RESET
end

function style.header(text: string): string
	return CSI .. "1;4m" .. text .. RESET
end

return style
