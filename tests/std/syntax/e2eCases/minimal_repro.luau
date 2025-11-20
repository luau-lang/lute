local printer = require("@std/syntax/printer")
local parser = require("@std/syntax/parser")
local query = require("@std/syntax/query")
local utils = require("@std/syntax/utils")

local demo = [[

local tbl = {
    a = 1,
}

]]

local ast = parser.parseblock(demo)

local replacements = {}

local tbl = query.findallfromroot(ast, utils.isExprTable):foreach(function(n)
	for i, entry in n.entries do
		replacements[entry] = `a{i} = "hello",`
	end
end)

print(printer.printnode(ast, replacements))
