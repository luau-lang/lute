local stringext = require("@std/stringext")
local syntax = require("@std/syntax")

local doc = require("./doc")
local render = require("./render")
local lower = require("./lower")
local trivia = require("./trivia")

local function toDoc(parseResult: syntax.CstParseResult): doc.Doc
	local body = lower.block(parseResult.root)
	local separator = if #parseResult.root.statements > 0 then doc.newline else doc.none
	local trailing = trivia.leadingDoc(parseResult.eof)
	return doc.concat({ body, separator, trailing })
end

local function format(source: string, options: render.Options?): string
	local parseResult = syntax.parse(source)
	local rendered = render.render(toDoc(parseResult), options)
	return `{stringext.trim(rendered)}\n`
end

return {
	toDoc = toDoc,
	format = format,
}
