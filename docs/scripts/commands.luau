--[[
	Command documentation generator.
	
	This script parses help text directly from lute source files and generates
	markdown documentation files in the docs/cli/ directory.
	
	Sources:
	- C++ help strings from lute/cli/src/climain.cpp
	- Luau printHelp() functions from lute/cli/commands/*/init.luau
	
	Usage: cd docs && lute scripts/commands.luau
]]

local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")

--[[ ========== HELP TEXT PARSING ========== ]]

-- Extract a C++ raw string literal: R"(...)"
local function extractCppRawString(content: string, varName: string): string?
	-- Match the variable assignment and capture content between R"( and )";
	local startPattern = `static const char%* {varName} = R"%(`
	local startPos = string.find(content, startPattern)
	if not startPos then
		return nil
	end

	local contentStart = startPos + #startPattern - #"R\"(" + #"R\"("
	contentStart = string.find(content, 'R"%(', startPos)
	if not contentStart then
		return nil
	end
	contentStart = contentStart + 3 -- Skip R"(

	local contentEnd = string.find(content, '%)";', contentStart)
	if not contentEnd then
		return nil
	end

	return string.sub(content, contentStart, contentEnd - 1)
end

-- Extract help text from a Luau printHelp() function
local function extractLuauHelpText(content: string): string?
	-- Look for print([[ ... ]]) or print(USAGE) followed by print([[ ... ]])
	-- First try to find a USAGE variable
	local usage = string.match(content, 'local USAGE = "([^"]+)"')

	-- Find the printHelp function
	local helpFuncStart = string.find(content, "local function printHelp%(%)")
	if not helpFuncStart then
		return nil
	end

	-- Find the end of the function (next "end" at the same indentation level)
	local helpFuncEnd = string.find(content, "\nend", helpFuncStart)
	if not helpFuncEnd then
		return nil
	end

	local helpFunc = string.sub(content, helpFuncStart, helpFuncEnd)

	-- Extract all [[ ... ]] blocks
	local blocks = {}
	local pos = 1
	while true do
		local blockStart = string.find(helpFunc, "%[%[", pos)
		if not blockStart then
			break
		end
		local blockEnd = string.find(helpFunc, "%]%]", blockStart)
		if not blockEnd then
			break
		end
		local block = string.sub(helpFunc, blockStart + 2, blockEnd - 1)
		table.insert(blocks, block)
		pos = blockEnd + 2
	end

	if #blocks == 0 then
		return nil
	end

	-- Combine usage line with the help block
	local helpText = table.concat(blocks, "\n")
	if usage and not string.match(helpText, "^Usage:") then
		helpText = "Usage: " .. usage .. "\n" .. helpText
	end

	return helpText
end

-- Parse the main HELP_STRING to get command descriptions
local function parseMainHelp(mainHelp: string): { [string]: { description: string, usage: string?, options: string? } }
	local commands = {}

	-- Parse the Commands section
	local commandsSection = string.match(mainHelp, "Commands:\n(.-)\n\n")
	if commandsSection then
		for line in string.gmatch(commandsSection, "([^\n]+)") do
			local name, desc = string.match(line, "^%s*([%w]+)%s+.-(%u.+)$")
			if name and desc then
				name = string.gsub(name, "%s*%(default%)", "")
				commands[name] = { description = stringext.trim(desc) }
			end
		end
	end

	-- Parse individual command sections (e.g., "Run Options", "Check Options", etc.)
	local sections = {
		{ pattern = "Run Options[^\n]*:\n(.-)\n\n", name = "run" },
		{ pattern = "Check Options[^\n]*:\n(.-)\n\n", name = "check" },
		{ pattern = "Compile Options[^\n]*:\n(.-)\n\n", name = "compile" },
		{ pattern = "Setup Options[^\n]*:\n(.-)\n\n", name = "setup" },
		{ pattern = "Transform Options[^\n]*:\n(.-)\n\n", name = "transform" },
		{ pattern = "Lint Options[^\n]*:\n(.-)\n\n", name = "lint" },
	}

	for _, section in sections do
		local content = string.match(mainHelp, section.pattern)
		if content and commands[section.name] then
			-- Extract usage line
			local usage = string.match(content, "lute [^\n]+")
			if usage then
				commands[section.name].usage = usage
			end
			-- Extract options (lines starting with --) and join continuation lines
			local opts = {}
			local currentOpt = nil
			for line in string.gmatch(content, "([^\n]+)") do
				if string.match(line, "^%s+%-%-") then
					-- This is a new option line
					if currentOpt then
						table.insert(opts, currentOpt)
					end
					currentOpt = stringext.trim(line)
				elseif currentOpt and string.match(line, "^%s%s%s%s%s%s") then
					-- This is a continuation line (heavily indented)
					currentOpt = currentOpt .. " " .. stringext.trim(line)
				end
			end
			if currentOpt then
				table.insert(opts, currentOpt)
			end
			if #opts > 0 then
				commands[section.name].options = table.concat(opts, "\n")
			end
		end
	end

	return commands
end

--[[ ========== MARKDOWN GENERATION ========== ]]

local function formatOptionsAsMarkdown(optionsText: string): string
	local lines = {}
	local currentOption = nil
	local currentDesc = {}

	for line in string.gmatch(optionsText .. "\n", "([^\n]*)\n") do
		local trimmed = stringext.trim(line)
		if trimmed == "" then
			continue
		end

		-- Check if this line starts with an option flag
		if string.match(trimmed, "^%-") then
			-- Flush previous option
			if currentOption then
				table.insert(lines, `### \`{currentOption}\``)
				table.insert(lines, "")
				if #currentDesc > 0 then
					table.insert(lines, table.concat(currentDesc, " "))
					table.insert(lines, "")
				end
			end

			-- Parse the option - extract just the flag part, not the description
			-- The flag ends when we hit multiple spaces followed by a capital letter
			
			local flags, desc
			
			-- First, try to split on double+ spaces (common separator)
			local beforeSpaces, afterSpaces = string.match(trimmed, "^(.-)%s%s+(.+)$")
			
			if beforeSpaces and afterSpaces then
				-- Now extract just the option flags from beforeSpaces
				-- Options are: -x, --long, --long=VAL, --long <val>, --long [val]
				flags = stringext.trim(beforeSpaces)
				desc = stringext.trim(afterSpaces)
			else
				-- No double space found, whole line is probably just the option
				flags = trimmed
				desc = nil
			end

			currentOption = flags
			if desc and desc ~= "" then
				currentDesc = { desc }
			else
				currentDesc = {}
			end
		elseif currentOption then
			-- Continuation of description (starts with spaces in original)
			table.insert(currentDesc, trimmed)
		end
	end

	-- Flush last option
	if currentOption then
		table.insert(lines, `### \`{currentOption}\``)
		table.insert(lines, "")
		if #currentDesc > 0 then
			table.insert(lines, table.concat(currentDesc, " "))
			table.insert(lines, "")
		end
	end

	return table.concat(lines, "\n")
end

local function formatExamplesAsMarkdown(examplesText: string): string
	local lines = {}

	for line in string.gmatch(examplesText .. "\n", "([^\n]*)\n") do
		local trimmed = stringext.trim(line)
		if trimmed == "" then
			continue
		end

		-- Check if this is a command line (starts with "lute ")
		if string.match(trimmed, "^lute ") then
			-- Check for inline description (separated by multiple spaces)
			-- Match pattern: "lute command args  Description text here"
			local cmd, desc = string.match(trimmed, "^(lute .-)%s%s+([A-Z].+)$")
			if cmd and desc then
				table.insert(lines, desc .. ":")
				table.insert(lines, "")
				table.insert(lines, "```bash")
				table.insert(lines, stringext.trim(cmd))
				table.insert(lines, "```")
				table.insert(lines, "")
			else
				-- No inline description, just output the command
				table.insert(lines, "```bash")
				table.insert(lines, trimmed)
				table.insert(lines, "```")
				table.insert(lines, "")
			end
		end
	end

	return table.concat(lines, "\n")
end

type CommandInfo = {
	name: string,
	description: string,
	usage: string?,
	options: string?,
	arguments: string?,
	examples: string?,
}

local function parseHelpTextFull(name: string, helpText: string, fallbackDesc: string?): CommandInfo
	local info: CommandInfo = {
		name = name,
		description = fallbackDesc or "",
	}

	-- Extract usage line (remove "Usage: " prefix if present)
	local usageLine = string.match(helpText, "Usage:%s*([^\n]+)")
	if usageLine then
		-- Remove redundant "Usage: " prefix if the help text itself starts with it
		usageLine = string.gsub(usageLine, "^Usage:%s*", "")
		info.usage = usageLine
	end

	-- Extract description (first paragraph after usage, before any section headers)
	-- Only use it if it doesn't look like a section header
	local afterUsage = string.match(helpText, "Usage:[^\n]*\n\n([^\n]+)")
	if afterUsage then
		afterUsage = stringext.trim(afterUsage)
		-- Skip if it looks like a section header (e.g., "Run Options:", "OPTIONS:")
		if not string.match(afterUsage, "^%u[%w%s]*:$") and not string.match(afterUsage, "^%-") then
			info.description = afterUsage
		end
	end
	
	-- Keep fallback description if we didn't find a good one
	if info.description == "" and fallbackDesc then
		info.description = fallbackDesc
	end

	-- Extract OPTIONS section
	local optionsMatch = string.match(helpText, "OPTIONS?:?\n(.-)\n[A-Z]+:")
		or string.match(helpText, "Options:?\n(.-)\n[A-Z]+:")
		or string.match(helpText, "OPTIONS?:?\n(.-)$")
		or string.match(helpText, "Options:?\n(.-)$")
	if optionsMatch then
		info.options = stringext.trim(optionsMatch)
	end

	-- Extract PATHS/Arguments section
	local pathsMatch = string.match(helpText, "PATHS?:?\n(.-)\n[A-Z]+:") or string.match(helpText, "PATHS?:?\n(.-)$")
	if pathsMatch then
		info.arguments = stringext.trim(pathsMatch)
	end

	-- Extract EXAMPLES section
	local examplesMatch = string.match(helpText, "EXAMPLES?:?\n(.-)\n[A-Z]+:")
		or string.match(helpText, "EXAMPLES?:?\n(.-)$")
	if examplesMatch then
		info.examples = stringext.trim(examplesMatch)
	end

	return info
end

local function generateCommandMarkdown(info: CommandInfo): string
	local lines = {}

	-- Title (just the command name, no "lute " prefix)
	table.insert(lines, `# {info.name}`)
	table.insert(lines, "")

	-- Description
	if info.description and info.description ~= "" then
		table.insert(lines, info.description)
		table.insert(lines, "")
	end

	-- Usage
	if info.usage then
		table.insert(lines, "## Usage")
		table.insert(lines, "")
		table.insert(lines, "```bash")
		table.insert(lines, info.usage)
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	-- Options
	if info.options and info.options ~= "" then
		table.insert(lines, "## Options")
		table.insert(lines, "")
		table.insert(lines, formatOptionsAsMarkdown(info.options))
	end

	-- Arguments
	if info.arguments and info.arguments ~= "" then
		table.insert(lines, "## Arguments")
		table.insert(lines, "")
		table.insert(lines, info.arguments)
		table.insert(lines, "")
	end

	-- Examples
	if info.examples and info.examples ~= "" then
		table.insert(lines, "## Examples")
		table.insert(lines, "")
		table.insert(lines, formatExamplesAsMarkdown(info.examples))
	end

	return table.concat(lines, "\n")
end

local function generateIndexMarkdown(commands: { CommandInfo }): string
	local lines = {}

	-- Frontmatter for sidebar ordering
	table.insert(lines, "---")
	table.insert(lines, "order: 2")
	table.insert(lines, "---")
	table.insert(lines, "")
	table.insert(lines, "# CLI Reference")
	table.insert(lines, "")
	table.insert(
		lines,
		"Lute provides a command-line interface for running, type checking, compiling, testing, and linting Luau code."
	)
	table.insert(lines, "")
	table.insert(lines, "## Usage")
	table.insert(lines, "")
	table.insert(lines, "```bash")
	table.insert(lines, "lute <command> [options] [arguments...]")
	table.insert(lines, "```")
	table.insert(lines, "")
	table.insert(lines, "If no command is specified, `run` is used by default.")
	table.insert(lines, "")
	table.insert(lines, "## Commands")
	table.insert(lines, "")
	table.insert(lines, "| Command | Description |")
	table.insert(lines, "| ------- | ----------- |")

	for _, cmd in commands do
		local desc = cmd.description
		-- Get first sentence
		local firstSentence = string.match(desc, "^(.-)%.%s") or string.match(desc, "^(.-)%.$") or desc
		if not string.match(firstSentence, "%.$") then
			firstSentence = firstSentence .. "."
		end
		table.insert(lines, `| [{cmd.name}](./{cmd.name}) | {firstSentence} |`)
	end

	table.insert(lines, "")
	table.insert(lines, "## Global Options")
	table.insert(lines, "")
	table.insert(lines, "| Option | Description |")
	table.insert(lines, "| ------ | ----------- |")
	table.insert(lines, "| `-h`, `--help` | Display help message for the command. |")
	table.insert(lines, "| `--version` | Show the lute version. |")
	table.insert(lines, "")

	return table.concat(lines, "\n")
end

--[[ ========== MAIN ========== ]]

local function main()
	-- Paths (relative to docs directory)
	local cliDocsPath = path.join(process.cwd(), "cli")
	local climainPath = path.join(process.cwd(), "..", "lute", "cli", "src", "climain.cpp")
	local commandsDir = path.join(process.cwd(), "..", "lute", "cli", "commands")

	-- Create output directory
	fs.createdirectory(cliDocsPath, { makeparents = true })

	print("Parsing CLI help text from source files...")

	-- Read C++ source
	local cppSource = fs.readfiletostring(climainPath)

	-- Extract and parse main help string
	local mainHelp = extractCppRawString(cppSource, "HELP_STRING")
	if not mainHelp then
		error("Could not find HELP_STRING in climain.cpp")
	end

	local mainHelpInfo = parseMainHelp(mainHelp)

	-- Collect all command info
	local allCommands: { CommandInfo } = {}

	-- Process C++ command help strings
	local cppCommandVars = {
		run = "RUN_HELP_STRING",
		check = "CHECK_HELP_STRING",
		compile = "COMPILE_HELP_STRING",
	}

	for name, varName in cppCommandVars do
		local helpText = extractCppRawString(cppSource, varName)
		local fallbackInfo = mainHelpInfo[name]
		local info: CommandInfo

		if helpText then
			info = parseHelpTextFull(name, helpText, fallbackInfo and fallbackInfo.description)
			-- Merge with main help info for options/usage if not in specific help
			if fallbackInfo then
				if not info.options and fallbackInfo.options then
					info.options = fallbackInfo.options
				end
			end
		elseif fallbackInfo then
			info = {
				name = name,
				description = fallbackInfo.description,
				usage = fallbackInfo.usage,
				options = fallbackInfo.options,
			}
		else
			continue
		end

		table.insert(allCommands, info)
		print(`  Parsed C++ command: {name}`)
	end

	-- Process commands only defined in main HELP_STRING (setup, transform)
	for name, fallbackInfo in mainHelpInfo do
		-- Skip commands we already processed
		if cppCommandVars[name] then
			continue
		end

		-- Check if there's a Luau command with a printHelp
		local luauPath = path.join(commandsDir, name, "init.luau")
		if fs.exists(luauPath) then
			local content = fs.readfiletostring(luauPath)
			local helpText = extractLuauHelpText(content)
			if helpText then
				local info = parseHelpTextFull(name, helpText, fallbackInfo.description)
				table.insert(allCommands, info)
				print(`  Parsed Luau command: {name}`)
				continue
			end
		end

		-- Use info from main help
		local info: CommandInfo = {
			name = name,
			description = fallbackInfo.description,
			usage = fallbackInfo.usage,
			options = fallbackInfo.options,
		}
		table.insert(allCommands, info)
		print(`  Parsed from main help: {name}`)
	end

	-- Process Luau commands not in main help (e.g., test)
	for _, entry in fs.listdirectory(commandsDir) do
		if entry.type == "dir" and entry.name ~= "lib" and entry.name ~= "helloworld" then
			-- Check if already processed
			local found = false
			for _, cmd in allCommands do
				if cmd.name == entry.name then
					found = true
					break
				end
			end

			if not found then
				local initPath = path.join(commandsDir, entry.name, "init.luau")
				if fs.exists(initPath) then
					local content = fs.readfiletostring(initPath)
					local helpText = extractLuauHelpText(content)
					if helpText then
						local info = parseHelpTextFull(entry.name, helpText, nil)
						table.insert(allCommands, info)
						print(`  Parsed Luau command: {entry.name}`)
					end
				end
			end
		end
	end

	-- Sort by name
	table.sort(allCommands, function(a, b)
		return a.name < b.name
	end)

	-- Generate index
	local indexMarkdown = generateIndexMarkdown(allCommands)
	local indexPath = path.join(cliDocsPath, "index.md")
	fs.writestringtofile(indexPath, indexMarkdown)
	print(`Generated {indexPath}`)

	-- Generate individual pages
	for _, info in allCommands do
		local markdown = generateCommandMarkdown(info)
		local filePath = path.join(cliDocsPath, info.name .. ".md")
		fs.writestringtofile(filePath, markdown)
		print(`Generated {filePath}`)
	end

	print(`\nGenerated documentation for {#allCommands} commands from source files!`)
end

main()
