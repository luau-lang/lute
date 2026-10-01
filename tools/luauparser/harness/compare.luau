--!nocheck
-- Compares our pure-Luau parser against the native reference parser
-- (@lute/syntax/parser) for exact structural equality of the produced CST.
--
-- Usage:
--   lute run tools/luauparser/harness/compare.luau            -- run built-in cases
--   lute run tools/luauparser/harness/compare.luau <file...>  -- compare specific files
--   lute run tools/luauparser/harness/compare.luau @list.txt  -- compare a newline-separated file list

local reference = require("@lute/syntax/parser")
local mine = require("../src/parser")
local serialize = require("./serialize")

local fs = require("@lute/fs")

local function readFile(path: string): string
	local handle = fs.open(path, "r")
	local contents = fs.read(handle)
	fs.close(handle)
	return contents
end

type Case = { name: string, source: string, mode: "parse" | "expr" }

local function firstDiff(a: string, b: string): string
	local la = string.split(a, "\n")
	local lb = string.split(b, "\n")
	local n = math.max(#la, #lb)
	for i = 1, n do
		if la[i] ~= lb[i] then
			local lo = math.max(1, i - 4)
			local out = {}
			for j = lo, math.min(n, i + 4) do
				local marker = if j == i then ">>" else "  "
				table.insert(out, string.format("%s ref  %3d| %s", marker, j, la[j] or "<none>"))
				table.insert(out, string.format("%s mine %3d| %s", marker, j, lb[j] or "<none>"))
			end
			return table.concat(out, "\n")
		end
	end
	return "(identical textually but compared unequal?)"
end

local function runCase(c: Case): (boolean, string?)
	local okRef, ref = pcall(function()
		if c.mode == "expr" then
			return reference.parseExpr(c.source)
		end
		return reference.parse(c.source)
	end)
	local okMine, got = pcall(function()
		if c.mode == "expr" then
			return mine.parseExpr(c.source)
		end
		return mine.parse(c.source)
	end)

	if not okRef and not okMine then
		return true, nil -- both error: treat as match (error-shape matching is a later refinement)
	end
	if okRef ~= okMine then
		return false,
			string.format(
				"error mismatch: reference %s, mine %s\n  ref: %s\n  mine: %s",
				tostring(okRef),
				tostring(okMine),
				tostring(ref),
				tostring(got)
			)
	end

	local sRef = serialize(ref)
	local sMine = serialize(got)
	if sRef == sMine then
		return true, nil
	end
	return false, firstDiff(sRef, sMine)
end

local cases: { Case } = {
	{ name = "empty", source = "", mode = "parse" },
	{ name = "local-number", source = "local x = 1", mode = "parse" },
	{ name = "local-binary", source = "local x = 1 + 2", mode = "parse" },
	{ name = "local-multi", source = "local a, b, c = 1, 2, 3", mode = "parse" },
	{ name = "local-none", source = "local x", mode = "parse" },
	{ name = "precedence", source = "local x = 1 + 2 * 3 ^ 4 - 5", mode = "parse" },
	{ name = "unary", source = "local x = -1 + not true", mode = "parse" },
	{ name = "concat", source = "local x = 1 .. 2 .. 3", mode = "parse" },
	{ name = "bools", source = "local x = true\nlocal y = false\nlocal z = nil", mode = "parse" },
	{ name = "group", source = "local x = (1 + 2) * 3", mode = "parse" },
	{ name = "integer", source = "local x = 1i", mode = "parse" },
	{ name = "hex", source = "local x = 0xFF", mode = "parse" },
	{ name = "float", source = "local x = 3.14e10", mode = "parse" },
	{ name = "underscore-num", source = "local x = 1_000_000", mode = "parse" },
	{ name = "comment-leading", source = "-- hello\nlocal x = 1", mode = "parse" },
	{ name = "comment-trailing", source = "local x = 1 -- trailing\nlocal y = 2", mode = "parse" },
	{ name = "block-comment", source = "local x = --[[ inline ]] 1", mode = "parse" },
	{ name = "do-block", source = "do\n\tlocal x = 1\nend", mode = "parse" },
	{ name = "do-empty", source = "do end", mode = "parse" },
	{ name = "while", source = "while true do\n\tx = 1\nend", mode = "parse" },
	{ name = "repeat", source = "repeat\n\tx = 1\nuntil false", mode = "parse" },
	{ name = "assign", source = "x = 1", mode = "parse" },
	{ name = "assign-multi", source = "x, y = 1, 2", mode = "parse" },
	{ name = "compound", source = "x += 1", mode = "parse" },
	{ name = "indexname", source = "local x = a.b.c", mode = "parse" },
	{ name = "indexexpr", source = "local x = a[1][2]", mode = "parse" },
	{ name = "call", source = "f(1, 2, 3)", mode = "parse" },
	{ name = "call-empty", source = "f()", mode = "parse" },
	{ name = "methodcall", source = "a:b(1)", mode = "parse" },
	{ name = "mixed-suffix", source = "local x = a.b[1].c(2)", mode = "parse" },
	{ name = "varargs-local", source = "local x = ...", mode = "parse" },
	{ name = "trailing-newline", source = "local x = 1\n", mode = "parse" },
	{ name = "semicolons", source = "local x = 1; local y = 2;", mode = "parse" },
	{ name = "shadow", source = "local x = 1\nlocal x = x", mode = "parse" },
	{ name = "expr-mode", source = "1 + 2 * 3", mode = "expr" },
	{ name = "expr-call", source = "f(a, b)", mode = "expr" },
	{ name = "str-double", source = 'local x = "hello"', mode = "parse" },
	{ name = "str-single", source = "local x = 'hello'", mode = "parse" },
	{ name = "str-escape", source = 'local x = "a\\nb\\tc"', mode = "parse" },
	{ name = "str-raw", source = "local x = [[hello]]", mode = "parse" },
	{ name = "str-raw-depth", source = "local x = [==[hello]==]", mode = "parse" },
	{ name = "str-call", source = 'print("hi")', mode = "parse" },
	{ name = "str-call-bare", source = 'require "mod"', mode = "parse" },
	{ name = "table-empty", source = "local x = {}", mode = "parse" },
	{ name = "table-list", source = "local x = {1, 2, 3}", mode = "parse" },
	{ name = "table-record", source = "local x = {a = 1, b = 2}", mode = "parse" },
	{ name = "table-general", source = "local x = {[1] = 2, [k] = v}", mode = "parse" },
	{ name = "table-mixed", source = "local x = {1, a = 2, [3] = 4; 5}", mode = "parse" },
	{ name = "table-nested", source = "local x = {{1}, {a = {2}}}", mode = "parse" },
	{ name = "table-call", source = "f{1, 2}", mode = "parse" },
	{ name = "table-trailing", source = "local x = {\n\t1,\n\t2,\n}", mode = "parse" },
	{ name = "if", source = "if x then\n\ty = 1\nend", mode = "parse" },
	{ name = "if-else", source = "if x then\n\ty = 1\nelse\n\ty = 2\nend", mode = "parse" },
	{ name = "if-elseif", source = "if x then\n\ta()\nelseif y then\n\tb()\nelseif z then\n\tc()\nelse\n\td()\nend", mode = "parse" },
	{ name = "if-nested", source = "if a then if b then c() end end", mode = "parse" },
	{ name = "for-num", source = "for i = 1, 10 do\n\tf(i)\nend", mode = "parse" },
	{ name = "for-num-step", source = "for i = 1, 10, 2 do\n\tf(i)\nend", mode = "parse" },
	{ name = "for-in", source = "for k, v in pairs(t) do\n\tf(k, v)\nend", mode = "parse" },
	{ name = "for-in-single", source = "for x in it do\n\tg(x)\nend", mode = "parse" },
	{ name = "nested-loops", source = "for i = 1, 3 do\n\twhile true do\n\t\tbreak\n\tend\nend", mode = "parse" },
	{ name = "func-stat", source = "function f(a, b)\n\treturn a + b\nend", mode = "parse" },
	{ name = "func-empty", source = "function f()\nend", mode = "parse" },
	{ name = "func-vararg", source = "function f(a, ...)\n\treturn ...\nend", mode = "parse" },
	{ name = "func-method", source = "function t.a.b:m(x)\n\treturn x\nend", mode = "parse" },
	{ name = "func-dotted", source = "function t.a.b(x)\n\treturn x\nend", mode = "parse" },
	{ name = "local-func", source = "local function f(x)\n\treturn f(x)\nend", mode = "parse" },
	{ name = "func-expr", source = "local f = function(a, b) return a end", mode = "parse" },
	{ name = "func-generics", source = "local f = function<T, U>(a) return a end", mode = "parse" },
	{ name = "func-generic-pack", source = "local f = function<T, U...>(a) return a end", mode = "parse" },
	{ name = "func-nested", source = "local function outer()\n\tlocal function inner()\n\t\treturn 1\n\tend\n\treturn inner\nend", mode = "parse" },
	{ name = "func-call-chain", source = "local x = f(1)(2)(3)", mode = "parse" },
	{ name = "callback", source = "f(function() return 1 end)", mode = "parse" },
	{ name = "toplevel-vararg", source = "local x = ...", mode = "parse" },
	{ name = "local-annot", source = "local x: number = 1", mode = "parse" },
	{ name = "local-annot-multi", source = "local x: number, y: string = 1, 'a'", mode = "parse" },
	{ name = "type-ref-generic", source = "local x: Map<string, number> = y", mode = "parse" },
	{ name = "type-prefix", source = "local x: mod.Type = y", mode = "parse" },
	{ name = "type-optional", source = "local x: number? = y", mode = "parse" },
	{ name = "type-union", source = "local x: number | string | boolean = y", mode = "parse" },
	{ name = "type-intersection", source = "local x: A & B & C = y", mode = "parse" },
	{ name = "type-union-optional", source = "local x: (number | string)? = y", mode = "parse" },
	{ name = "type-table", source = "local x: { a: number, b: string } = y", mode = "parse" },
	{ name = "type-table-indexer", source = "local x: { [string]: number } = y", mode = "parse" },
	{ name = "type-table-array", source = "local x: { number } = y", mode = "parse" },
	{ name = "type-table-access", source = "local x: { read a: number, write b: string } = y", mode = "parse" },
	{ name = "type-typeof", source = "local x: typeof(y) = y", mode = "parse" },
	{ name = "type-func", source = "local x: (number, string) -> boolean = y", mode = "parse" },
	{ name = "type-func-named", source = "local x: (a: number, b: string) -> () = y", mode = "parse" },
	{ name = "type-func-vararg", source = "local x: (...number) -> ...string = y", mode = "parse" },
	{ name = "type-func-generic", source = "local x: <T>(T) -> T = y", mode = "parse" },
	{ name = "func-param-annot", source = "function f(a: number, b: string): boolean\n\treturn true\nend", mode = "parse" },
	{ name = "func-ret-tuple", source = "function f(): (number, string)\n\treturn 1, 'a'\nend", mode = "parse" },
	{ name = "func-vararg-annot", source = "function f(...: number)\n\treturn ...\nend", mode = "parse" },
	{ name = "type-alias", source = "type Foo = number", mode = "parse" },
	{ name = "type-alias-generic", source = "type Map<K, V> = { [K]: V }", mode = "parse" },
	{ name = "type-alias-export", source = "export type Foo = string", mode = "parse" },
	{ name = "type-singleton", source = 'type Dir = "up" | "down"', mode = "parse" },
}

-- lute passes the script path as the first vararg; skip it.
local allArgs = table.pack(...)
local args = {}
for i = 2, allArgs.n do
	table.insert(args, allArgs[i])
end
local verbose = false
if #args > 0 then
	cases = {}
	for _, path in args do
		if string.sub(path, 1, 1) == "@" then
			-- @listfile: newline-separated list of paths to compare.
			verbose = true
			local list = readFile(string.sub(path, 2))
			for line in string.gmatch(list, "[^\n]+") do
				local ok, source = pcall(readFile, line)
				if ok then
					table.insert(cases, { name = line, source = source, mode = "parse" })
				end
			end
		else
			local ok, source = pcall(readFile, path)
			if ok then
				table.insert(cases, { name = path, source = source, mode = "parse" })
			end
		end
	end
end

local passed = 0
local failed = 0
for _, c in cases do
	local ok, msg = runCase(c)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("FAIL %s", c.name))
		if not verbose then
			print(msg)
			print("")
		end
	end
end

print(string.format("\n%d passed, %d failed (%d total)", passed, failed, passed + failed))
