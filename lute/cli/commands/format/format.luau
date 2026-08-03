local stringext = require("@std/stringext")

local function formatSource(source: string): string
	return stringext.trim(source) .. "\n"
end

return {
	formatSource = formatSource,
}
