-- lute-lint-global-ignore(unused_variable)
local cst = require("./cst")

local parser = {}

--- Parses `source` as a Luau script and returns the resulting CST.
function parser.parse(source: string): cst.CstParseResult
	error("not implemented")
end

--- Parses `source` as a single Luau expression and returns the resulting CST node.
function parser.parseExpr(source: string): cst.CstExpr
	error("not implemented")
end

return parser
