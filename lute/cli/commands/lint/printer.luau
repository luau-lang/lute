local fs = require("@std/fs")
local path = require("@std/path")
local stringext = require("@std/stringext")
local types = require("@lint")

local printerLib = {}

local TAB_SIZE = 4

local function formatLint(lint: types.LintViolation, sourceLines: { string }): string
	local lines = {}

	table.insert(lines, `{lint.severity}[{lint.lintname}]: {lint.message}\n`)

	local location = lint.location
	local filepath = if lint.sourcepath then path.format(lint.sourcepath) else "input"

	if location.beginLine == location.endLine then
		local gutterSize = math.floor(math.log10(location.endLine)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		-- Compute the number of tabs before the violation and within the violation
		local prelintTabs = stringext.count(sourceLines[location.beginLine], "\t", 1, location.beginColumn - 1)
		local lintTabs =
			stringext.count(sourceLines[location.beginLine], "\t", location.beginColumn, location.endColumn)
		-- Convert tabs in the source line to spaces
		local sourceLine =
			` {location.beginLine} │ {sourceLines[location.beginLine]:gsub("\t", string.rep(" ", TAB_SIZE))}`

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.beginLine}:{location.beginColumn}-{location.endColumn} ──`
		if #filepathLine < #sourceLine then
			filepathLine ..= string.rep("─", #sourceLine - #filepathLine)
		end

		table.insert(lines, filepathLine)
		table.insert(lines, `{blankGutter}│`)
		table.insert(lines, sourceLine)
		table.insert(
			lines,
			`{blankGutter}│ {string.rep(" ", location.beginColumn - 1 + (prelintTabs * (TAB_SIZE - 1)))}{string.rep(
				"^",
				location.endColumn - location.beginColumn + (lintTabs * (TAB_SIZE - 1))
			)}`
		)
		table.insert(lines, `{blankGutter}│`)
		table.insert(lines, "")
	else
		local gutterSize = math.floor(math.log10(location.endLine)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		local subbedSourceLine = sourceLines[location.beginLine]:gsub("\t", string.rep(" ", TAB_SIZE))
		local renderedSourceLines = {
			` {string.format(`%-{gutterSize - 2}d`, location.beginLine)} │ ╭ {subbedSourceLine}`,
		}
		local maxSourceLineLength = #renderedSourceLines[1]
		for lineNum = location.beginLine + 1, location.endLine do
			subbedSourceLine = sourceLines[lineNum]:gsub("\t", string.rep(" ", TAB_SIZE))
			table.insert(
				renderedSourceLines,
				` {string.format(`%-{gutterSize - 2}d`, lineNum)} │ │ {subbedSourceLine}`
			)
			maxSourceLineLength = math.max(maxSourceLineLength, #renderedSourceLines[#renderedSourceLines])
		end

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.beginLine}:{location.beginColumn}-{location.endLine}:{location.endColumn} ──`
		if #filepathLine < maxSourceLineLength then
			filepathLine ..= string.rep("─", maxSourceLineLength - #filepathLine)
		end

		table.insert(lines, filepathLine)
		table.insert(lines, `{blankGutter}│`)
		for _, line in renderedSourceLines do
			table.insert(lines, line)
		end
		table.insert(lines, `{blankGutter}│ ╰{string.rep("─", maxSourceLineLength - gutterSize - 8)}^`)
		table.insert(lines, `{blankGutter}│\n`)
	end

	if lint.suggestedfix then
		table.insert(lines, `Suggested fix: {lint.suggestedfix.fix}\n`)
	end

	if lint.target then
		table.insert(lines, `For additional info: {lint.target}\n`)
	end

	return table.concat(lines, "\n")
end

function printerLib.formatLintsWithSource(lints: { types.LintViolation }, sourceContent: string): string
	local sourceLines = sourceContent:split("\n")
	local parts = {}

	for _, lint in lints do
		table.insert(parts, formatLint(lint, sourceLines))
	end

	return table.concat(parts, "\n")
end

function printerLib.formatLintsWithPath(lints: { types.LintViolation }, sourcePath: path.Path): string
	return printerLib.formatLintsWithSource(lints, fs.readFileToString(sourcePath))
end

return table.freeze(printerLib)
