--!nonstrict
--[[
	example.luau — a tiny linter built on the pure-Luau parser.

	Demonstrates using `luauparser` as a drop-in alternative to the native
	`@lute/syntax` AST/CST APIs: parse source, walk the CST, report diagnostics
	with source locations. No native parser or AST API is involved.

	Run it:  lute run tools/luauparser/example.luau
]]

local luau = require("../luauparser")

-- A small sample program with a couple of lint-worthy lines.
local SOURCE = [[
local function area(r: number): number
	return 3.14 * r / 0
end

local function clamp(x)
	return if x < 0 then 0 else x
end

local total = (10 + 5) % 0
print(area(2), clamp(total))
]]

type Diagnostic = { line: number, column: number, message: string }

-- Rule: dividing (or taking a remainder) by the literal 0 is always NaN.
local function divideByZero(root): { Diagnostic }
	local out: { Diagnostic } = {}
	for _, node in luau.findAll(root, luau.is("expr", "binary")) do
		local op = node.operator.text
		local rhs = node.rhsOperand
		if (op == "/" or op == "//" or op == "%") and rhs.kind == "expr" and rhs.tag == "number" and rhs.value == 0 then
			table.insert(out, {
				line = node.location.beginLine,
				column = node.location.beginColumn,
				message = `dividing by zero with '{op}' always yields NaN; consider 'math.nan'`,
			})
		end
	end
	return out
end

-- Pretty-print a diagnostic against the offending source line.
local function report(source: string, d: Diagnostic)
	local lines = string.split(source, "\n")
	local text = lines[d.line] or ""
	print(string.format("%d:%d  warning  %s", d.line, d.column, d.message))
	print("   | " .. text)
	print("   | " .. string.rep(" ", math.max(0, d.column - 1)) .. "^")
	print("")
end

local result = luau.parse(SOURCE)
print(string.format("Parsed %d lines; root is a '%s' node with %d statements.\n", result.lines, result.root.tag, #result.root.statements))

local diagnostics = divideByZero(result.root)
for _, d in diagnostics do
	report(SOURCE, d)
end

print(string.format("%d diagnostic(s).", #diagnostics))
