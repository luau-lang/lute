local stringext = require("@std/stringext")

local function formatSource(source: string): string
	local trimmed = stringext.trim(source)
	return if trimmed == "" then trimmed else `{trimmed}\n`
end

return {
	formatSource = formatSource,
}
