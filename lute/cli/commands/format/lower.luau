const printer = require("@std/syntax/printer")
const syntax = require("@std/syntax")

const doc = require("./doc")
type Doc = doc.Doc

const function verbatim(node: syntax.CstNode): Doc
	return printer.printNode(node)
end

const lowerLib = {}

function lowerLib.block(node: syntax.CstStatBlock): Doc
	return verbatim(node)
end

function lowerLib.file(source: string): Doc
	const parseResult = syntax.parse(source)
	return doc.concat({
		lowerLib.block(parseResult.root),
		verbatim(parseResult.eof),
	})
end

return table.freeze(lowerLib)
