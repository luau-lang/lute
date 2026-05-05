local fs = require("@std/fs")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")

local util = {}

function util.printReplacement(testName: string, transformFn: (syntax.AstStatBlock) -> syntaxTypes.Replacements)
	local inFile = `./tests/std/syntax/snapshots/printer/{testName}.in`
	local source = fs.readFileToString(inFile)

	local ast = syntax.parse(source)

	local replacements = transformFn(ast.root)

	print(printer.printFile(ast, replacements))
end

return util
