const stringext = require("@std/stringext")

const lower = require("./lower")
const render = require("./render")

const formatLib = {}

function formatLib.formatSource(source: string, options: render.Options?): string
	const rendered = render.render(lower.file(source), options)
	const trimmed = stringext.trim(rendered)
	return if trimmed == "" then trimmed else `{trimmed}\n`
end

return table.freeze(formatLib)
