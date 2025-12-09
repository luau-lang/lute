local difftext = require("@batteries/difftext")
local richterm = require("@batteries/richterm")
local test = require("@std/test")

local diff = difftext.diff

-- Each diff operation has structure: { key: "EQUAL" | "ADD" | "DELETE", text: string }
-- Order matters - the sequence of operations defines the transformation

test.suite("myersdiff - bychar", function(suite)
	suite:case("identical strings", function(assert)
		local a = "abc"
		local b = "abc"
		local diffResult = diff(a, b, { byChar = true })
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "c")
	end)

	suite:case("single character change in middle", function(assert)
		local a = "abc"
		local b = "axc"
		local diffResult = diff(a, b, { byChar = true })
		-- a(EQUAL), b(DELETE), x(ADD), c(EQUAL)
		assert.eq(#diffResult, 4)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "x")
		assert.eq(diffResult[4].key, "EQUAL")
		assert.eq(diffResult[4].text, "c")
	end)

	suite:case("character addition at start", function(assert)
		local a = "bc"
		local b = "abc"
		local diffResult = diff(a, b, { byChar = true })
		-- a(ADD), b(EQUAL), c(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "ADD")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "c")
	end)

	suite:case("character addition at end", function(assert)
		local a = "ab"
		local b = "abc"
		local diffResult = diff(a, b, { byChar = true })
		-- a(EQUAL), b(EQUAL), c(ADD)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "c")
	end)

	suite:case("character deletion at start", function(assert)
		local a = "abc"
		local b = "bc"
		local diffResult = diff(a, b, { byChar = true })
		-- a(DELETE), b(EQUAL), c(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "c")
	end)

	suite:case("character deletion at end", function(assert)
		local a = "abc"
		local b = "ab"
		local diffResult = diff(a, b, { byChar = true })
		-- a(EQUAL), b(EQUAL), c(DELETE)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "DELETE")
		assert.eq(diffResult[3].text, "c")
	end)

	suite:case("multiple consecutive changes", function(assert)
		local a = "abc"
		local b = "xyz"
		local diffResult = diff(a, b, { byChar = true })
		-- a(DELETE), b(DELETE), c(DELETE), x(ADD), y(ADD), z(ADD)
		assert.eq(#diffResult, 6)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "a")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "b")
		assert.eq(diffResult[3].key, "DELETE")
		assert.eq(diffResult[3].text, "c")
		assert.eq(diffResult[4].key, "ADD")
		assert.eq(diffResult[4].text, "x")
		assert.eq(diffResult[5].key, "ADD")
		assert.eq(diffResult[5].text, "y")
		assert.eq(diffResult[6].key, "ADD")
		assert.eq(diffResult[6].text, "z")
	end)

	suite:case("empty to non-empty", function(assert)
		local a = ""
		local b = "hi"
		local diffResult = diff(a, b, { byChar = true })
		-- h(ADD), i(ADD)
		assert.eq(#diffResult, 2)
		assert.eq(diffResult[1].key, "ADD")
		assert.eq(diffResult[1].text, "h")
		assert.eq(diffResult[2].key, "ADD")
		assert.eq(diffResult[2].text, "i")
	end)

	suite:case("non-empty to empty", function(assert)
		local a = "hi"
		local b = ""
		local diffResult = diff(a, b, { byChar = true })
		-- h(DELETE), i(DELETE)
		assert.eq(#diffResult, 2)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "h")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "i")
	end)
end)

test.suite("myersdiff - byline", function(suite)
	suite:case("identical multiline strings", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nline2\nline3"
		local diffResult = diff(a, b)
		-- All lines should be EQUAL
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("add line at start", function(assert)
		local a = "line2\nline3"
		local b = "line1\nline2\nline3"
		local diffResult = diff(a, b)
		-- line1(ADD), line2(EQUAL), line3(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "ADD")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("add line at end", function(assert)
		local a = "line1\nline2"
		local b = "line1\nline2\nline3"
		local diffResult = diff(a, b)
		-- line1(EQUAL), line2(EQUAL), line3(ADD)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("add line in middle", function(assert)
		local a = "line1\nline3"
		local b = "line1\nline2\nline3"
		local diffResult = diff(a, b)
		-- line1(EQUAL), line2(ADD), line3(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "ADD")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("delete line at start", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line2\nline3"
		local diffResult = diff(a, b)
		-- line1(DELETE), line2(EQUAL), line3(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("delete line at end", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nline2"
		local diffResult = diff(a, b)
		-- line1(EQUAL), line2(EQUAL), line3(DELETE)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "EQUAL")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "DELETE")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("delete line in middle", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nline3"
		local diffResult = diff(a, b)
		-- line1(EQUAL), line2(DELETE), line3(EQUAL)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "EQUAL")
		assert.eq(diffResult[3].text, "line3")
	end)

	suite:case("modify single line", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nmodified\nline3"
		local diffResult = diff(a, b)
		-- line1(EQUAL), line2(DELETE), modified(ADD), line3(EQUAL)
		assert.eq(#diffResult, 4)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "modified")
		assert.eq(diffResult[4].key, "EQUAL")
		assert.eq(diffResult[4].text, "line3")
	end)

	suite:case("multiple line changes", function(assert)
		local a = "A\nB\nC\nD"
		local b = "A\nX\nC\nY\nD"
		local diffResult = diff(a, b)
		-- A(EQUAL), B(DELETE), X(ADD), C(EQUAL), Y(ADD), D(EQUAL)
		assert.eq(#diffResult, 6)
		assert.eq(diffResult[1].key, "EQUAL")
		assert.eq(diffResult[1].text, "A")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "B")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "X")
		assert.eq(diffResult[4].key, "EQUAL")
		assert.eq(diffResult[4].text, "C")
		assert.eq(diffResult[5].key, "ADD")
		assert.eq(diffResult[5].text, "Y")
		assert.eq(diffResult[6].key, "EQUAL")
		assert.eq(diffResult[6].text, "D")
	end)

	suite:case("empty to multiline", function(assert)
		local a = ""
		local b = "line1\nline2"
		local diffResult = diff(a, b)
		-- When splitting "" by "\n", we get {""}, so it's: ""(DELETE), line1(ADD), line2(ADD)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "")
		assert.eq(diffResult[2].key, "ADD")
		assert.eq(diffResult[2].text, "line1")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "line2")
	end)

	suite:case("multiline to empty", function(assert)
		local a = "line1\nline2"
		local b = ""
		local diffResult = diff(a, b)
		-- line1(DELETE), line2(DELETE), ""(ADD)
		assert.eq(#diffResult, 3)
		assert.eq(diffResult[1].key, "DELETE")
		assert.eq(diffResult[1].text, "line1")
		assert.eq(diffResult[2].key, "DELETE")
		assert.eq(diffResult[2].text, "line2")
		assert.eq(diffResult[3].key, "ADD")
		assert.eq(diffResult[3].text, "")
	end)
end)

test.suite("printdiff", function(suite)
	local function composeDetailedRemoval(str: string, changedCharPos: { [number]: true }, sideHeader: string?)
		local composed = richterm.brightRed(`- {sideHeader or ""}`)
		for i = 1, #str do
			if changedCharPos[i] then
				composed ..= richterm.bgRed(str:sub(i, i))
			else
				composed ..= richterm.brightRed(str:sub(i, i))
			end
		end
		return composed
	end

	local function composeDetailedAddition(str: string, changedCharPos: { [number]: true }, sideHeader: string?)
		local composed = richterm.brightGreen(`+ {sideHeader or ""}`)
		for i = 1, #str do
			if changedCharPos[i] then
				composed ..= richterm.bgGreen(str:sub(i, i))
			else
				composed ..= richterm.brightGreen(str:sub(i, i))
			end
		end
		return composed
	end

	suite:case("printdiff default - simple addition", function(assert)
		local a = "line1\nline2"
		local b = "line1\nline2\nline3"
		local result = difftext.prettydiff(a, b)
		local lines = result:split("\n")

		assert.eq(#lines, 3)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], "line2")
		assert.eq(lines[3], richterm.brightGreen("+ line3"))
	end)

	suite:case("printdiff default - simple deletion", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nline3"
		local result = difftext.prettydiff(a, b)
		local lines = result:split("\n")

		assert.eq(#lines, 3)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], richterm.brightRed("- line2"))
		assert.eq(lines[3], "line3")
	end)

	suite:case("printdiff default - modification", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nmodified\nline3"
		local result = difftext.prettydiff(a, b)
		local lines = result:split("\n")

		assert.eq(#lines, 4)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], richterm.brightRed("- line2"))
		assert.eq(lines[3], richterm.brightGreen("+ modified"))
		assert.eq(lines[4], "line3")
	end)

	suite:case("printdiff default - unchanged lines", function(assert)
		local a = "line1\nline2\nline3"
		local b = "line1\nline2\nline3"
		local result = difftext.prettydiff(a, b)
		local lines = result:split("\n")

		assert.eq(#lines, 3)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], "line2")
		assert.eq(lines[3], "line3")
	end)

	suite:case("printdiff default - multiple changes", function(assert)
		local a = "A\nB\nC\nD"
		local b = "A\nX\nC\nY\nD"
		local result = difftext.prettydiff(a, b)
		local lines = result:split("\n")

		assert.eq(#lines, 6)
		assert.eq(lines[1], "A")
		assert.eq(lines[2], richterm.brightRed("- B"))
		assert.eq(lines[3], richterm.brightGreen("+ X"))
		assert.eq(lines[4], "C")
		assert.eq(lines[5], richterm.brightGreen("+ Y"))
		assert.eq(lines[6], "D")
	end)

	suite:case("printdiff default - with line numbers", function(assert)
		local a = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"
		local b = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"
		local result = difftext.prettydiff(a, b, {
			includeLineNumbers = true,
		})
		local lines = result:split("\n")

		assert.eq(#lines, 10)
		for i, line in lines do
			if i < 10 then
				assert.eq(line, `   {i}  {i}| line{i}`)
			else
				assert.eq(line, `  {i} {i}| line{i}`)
			end
		end
	end)

	suite:case("printdiff detailed - single line change", function(assert)
		local a = "hello world"
		local b = "hello wirld"
		local result = difftext.prettydiff(a, b, { detailed = true })
		local lines = result:split("\n")

		-- Detailed mode shows both old and new lines with character-level highlighting
		assert.eq(#lines, 2)
		assert.eq(
			lines[1],
			composeDetailedRemoval("hello world", { [8] = true }),
			`Not equal:\n{difftext.prettydiff(lines[1], composeDetailedRemoval("hello world", { [8] = true }))}`
		)
		assert.eq(lines[2], composeDetailedAddition("hello wirld", { [8] = true }))
	end)

	suite:case("printdiff detailed - multiple line changes", function(assert)
		local a = "line1\nold line\nline3"
		local b = "line1\nnew line\nline3"
		local result = difftext.prettydiff(a, b, { detailed = true })
		local lines = result:split("\n")

		local changedChars = {
			[1] = true,
			[2] = true,
			[3] = true,
		}

		-- Should have: line1, - old line, + new line, line3
		assert.eq(#lines, 4)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], composeDetailedRemoval("old line", changedChars))
		assert.eq(lines[3], composeDetailedAddition("new line", changedChars))
		assert.eq(lines[4], "line3")
	end)

	suite:case("printdiff detailed - unchanged lines", function(assert)
		local a = "line1\nline2"
		local b = "line1\nline2"
		local result = difftext.prettydiff(a, b, { detailed = true })
		local lines = result:split("\n")

		assert.eq(#lines, 2)
		assert.eq(lines[1], "line1")
		assert.eq(lines[2], "line2")
	end)

	suite:case("printdiff detailed - with line numbers", function(assert)
		local a = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nline10"
		local b = "line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8\nline9\nlineten"
		local result = difftext.prettydiff(a, b, {
			detailed = true,
			includeLineNumbers = true,
		})
		local lines = result:split("\n")

		assert.eq(#lines, 11)
		for i = 1, 9 do
			local line = lines[i]
			assert.eq(line, `   {i}  {i}| line{i}`)
		end
		assert.eq(lines[10], composeDetailedRemoval("line10", { [5] = true, [6] = true }, "10   | "))
		assert.eq(lines[11], composeDetailedAddition("lineten", { [5] = true, [6] = true, [7] = true }, "   10| "))
	end)
end)

test.run()
