local path = require("@std/path")
local types = require("./types")

local printerLib = {}

local function printLint(lint: types.LintViolation, sourceLines: { string }): ()
	print(`{lint.severity}[{lint.lintname}]: {lint.message}\n`)

	local location = {
		begin = { line = lint.location.begin.line + 1, column = lint.location.begin.column + 1 },
		["end"] = { line = lint.location["end"].line + 1, column = lint.location["end"].column + 1 },
	}
	local filepath = path.format(lint.sourcepath)

	if location.begin.line == location["end"].line then
		local gutterSize = math.floor(math.log10(location["end"].line)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		local sourceLine = ` {location.begin.line} │ {sourceLines[location.begin.line]}`

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.begin.line}:{location.begin.column}-{location["end"].column} ──`
		if #filepathLine < #sourceLine then
			filepathLine ..= string.rep("─", #sourceLine - #filepathLine)
		end

		print(filepathLine)
		print(`{blankGutter}│`)
		print(sourceLine)
		print(
			`{blankGutter}│ {string.rep(" ", location.begin.column - 1)}{string.rep(
				"^",
				location["end"].column - location.begin.column
			)}`
		)
		print(`{blankGutter}│`)
		print()
	else
		local gutterSize = math.floor(math.log10(location["end"].line)) + 3 -- + 2 for padding around line number
		local blankGutter = string.rep(" ", gutterSize)

		local renderedSourceLines = { ` {location.begin.line} │ ╭ {sourceLines[location.begin.line]}` }
		local maxSourceLineLength = #renderedSourceLines[1]
		for lineNum = location.begin.line + 1, location["end"].line do
			table.insert(renderedSourceLines, ` {lineNum} │ │ {sourceLines[lineNum]}`)
			maxSourceLineLength = math.max(maxSourceLineLength, #renderedSourceLines[#renderedSourceLines])
		end

		local filepathLine =
			`{blankGutter}┌── {filepath}:{location.begin.line}:{location.begin.column}-{location["end"].line}:{location["end"].column} ──`
		if #filepathLine < maxSourceLineLength then
			filepathLine ..= string.rep("─", maxSourceLineLength - #filepathLine)
		end

		print(filepathLine)
		print(`{blankGutter}│`)
		for _, line in renderedSourceLines do
			print(line)
		end
		print(`{blankGutter}│ ╰─{string.rep("─", location["end"].column - 2)}^`)
		print(`{blankGutter}│`)
		print()
	end
end

function printerLib.printLints(lints: { types.LintViolation }, sourceContent: string): ()
	local sourceLines = sourceContent:split("\n")

	for _, lint in lints do
		printLint(lint, sourceLines)
	end
end

return table.freeze(printerLib)
