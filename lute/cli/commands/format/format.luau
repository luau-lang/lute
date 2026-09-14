const stringext = require("@std/stringext")

const layout = require("./layout")
const lower = require("./lower")

const formatLib = {}

function formatLib.formatSource(source: string, options: layout.Options?): string
	const document = lower.file(source)
	const rendered = layout.render(document, options)
	const trimmed = stringext.trim(rendered)
	return if trimmed == "" then trimmed else `{trimmed}\n`
end

return table.freeze(formatLib)
