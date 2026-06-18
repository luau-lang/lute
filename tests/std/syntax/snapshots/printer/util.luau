local fs = require("@std/fs")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")
local syntaxTypes = require("@std/syntax/types")

local util = {}

function util.printReplacement(testName: string, transformFn: (syntax.CstStatBlock) -> syntaxTypes.Replacements)
	local inFile = `./tests/std/syntax/snapshots/printer/{testName}.in`
	local source = fs.readFileToString(inFile)

	local cst = syntax.parse(source)

	local replacements = transformFn(cst.root)

	print(printer.printFile(cst, replacements))
end

return util
