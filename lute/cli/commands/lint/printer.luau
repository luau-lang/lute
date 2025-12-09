local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local types = require("./types")

local printerLib = {}

local TAB_SIZE = 4

local function printLint(lint: types.LintViolation, sourceLines: { string }): ()
	print(`{lint.severity}[{lint.lintname}]: {lint.message}\n`)

	local location = lint.location
	local filepath = path.format(lint.sourcepath)

	if location.beginline == location.endline then
		local gutterSize = math.floor(math.log10(location.endline)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		-- Compute the number of tabs before the violation and within the violation
		local prelintTabs = stringext.count(sourceLines[location.beginline], "\t", 1, location.begincolumn - 1)
		local lintTabs =
			stringext.count(sourceLines[location.beginline], "\t", location.begincolumn, location.endcolumn)
		-- Convert tabs in the source line to spaces
		local sourceLine =
			` {location.beginline} │ {sourceLines[location.beginline]:gsub("\t", string.rep(" ", TAB_SIZE))}`

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.beginline}:{location.begincolumn}-{location.endcolumn} ──`
		if #filepathLine < #sourceLine then
			filepathLine ..= string.rep("─", #sourceLine - #filepathLine)
		end

		print(filepathLine)
		print(`{blankGutter}│`)
		print(sourceLine)
		print(
			`{blankGutter}│ {string.rep(" ", location.begincolumn - 1 + (prelintTabs * (TAB_SIZE - 1)))}{string.rep(
				"^",
				location.endcolumn - location.begincolumn + (lintTabs * (TAB_SIZE - 1))
			)}`
		)
		print(`{blankGutter}│`)
		print()
	else
		local gutterSize = math.floor(math.log10(location.endline)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		local subbedSourceLine = sourceLines[location.beginline]:gsub("\t", string.rep(" ", TAB_SIZE))
		local renderedSourceLines = {
			` {string.format(`%-{gutterSize - 2}d`, location.beginline)} │ ╭ {subbedSourceLine}`,
		}
		local maxSourceLineLength = #renderedSourceLines[1]
		for lineNum = location.beginline + 1, location.endline do
			subbedSourceLine = sourceLines[lineNum]:gsub("\t", string.rep(" ", TAB_SIZE))
			table.insert(
				renderedSourceLines,
				` {string.format(`%-{gutterSize - 2}d`, lineNum)} │ │ {subbedSourceLine}`
			)
			maxSourceLineLength = math.max(maxSourceLineLength, #renderedSourceLines[#renderedSourceLines])
		end

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.beginline}:{location.begincolumn}-{location.endline}:{location.endcolumn} ──`
		if #filepathLine < maxSourceLineLength then
			filepathLine ..= string.rep("─", maxSourceLineLength - #filepathLine)
		end

		print(filepathLine)
		print(`{blankGutter}│`)
		for _, line in renderedSourceLines do
			print(line)
		end
		print(`{blankGutter}│ ╰{string.rep("─", maxSourceLineLength - gutterSize - 8)}^`)
		print(`{blankGutter}│`)
		print()
	end
end

local function printLints(lints: { types.LintViolation }, sourceContent: string): ()
	local sourceLines = sourceContent:split("\n")

	for _, lint in lints do
		printLint(lint, sourceLines)
	end
end

function printerLib.printLints(lints: { types.LintViolation }, sourcePath: path.path): ()
	printLints(lints, fs.readfiletostring(sourcePath))
end

return table.freeze(printerLib)
