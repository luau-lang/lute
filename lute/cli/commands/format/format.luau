const stringext = require("@std/stringext")

const formatLib = {}

function formatLib.formatSource(source: string): string
	const trimmed = stringext.trim(source)
	return if trimmed == "" then trimmed else `{trimmed}\n`
end

return table.freeze(formatLib)
