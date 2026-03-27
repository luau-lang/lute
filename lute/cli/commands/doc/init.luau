local cli = require("@batteries/cli")
local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")
local typeprinter = require("@std/syntax/typeprinter")

local USAGE = "Usage: lute doc [OPTIONS] [...MODULE_PATHS]"
local DEFAULT_OUTPUT_DIR = path.resolve(process.cwd(), "docs")

local STDLIB_MODULE_ALIASES = {
	assert = "assertions",
	fs = "fslib",
	io = "iolib",
	process = "processlib",
	task = "tasklib",
	path = "pathlib",
	system = "systemlib",
	trivia = "retrieverLib",
	visitor = "visitorlib",
	query = "queryLib",
	printer = "printerLib",
}

local tripleDashCommentPattern = "^%s*%-%-%-%s?(.*)$" -- `---`
local blockCommentStartPattern = "^%s*%-%-%[(=*)%[" -- `--[[` or `--[=[` etc.
local whitespacePattern = "^%s*$"

type Definition = {
	name: string,
	signature: string,
	doc: string?,
}

local function printHelp()
	print(USAGE)
	print([[
Generate Markdown documentation for Luau module(s).

OPTIONS:
  -h, --help              Show this help message
  -o, --output=DIR        Output directory for generated docs (default: ./docs in current working directory)

MODULE_PATHS:
  Path(s) to Luau module(s) to generate documentation for. Only files with .luau or .lua extensions will be processed.
  Paths can be absolute or relative to the current working directory.

EXAMPLES:
  lute doc definitions                                 Generate docs for definitions module to the default directory ./docs
  lute doc --output ./my-docs-folder definitions       Generate docs for definitions module to custom directory ./my-docs-folder
  lute doc definitions lute/std/libs                   Generate docs for specific modules located at ./definitions and ./lute/std/libs
  lute doc ./absolute/module/path                      Generate docs for module at the specified absolute path
]])
end

local function collectDocs(content: string, moduleAlias: path.Pathlike): { [string]: string }
	local lines = string.split(content, "\n")
	local pendingDoc = {}
	local docMap = {}
	local inBlock = false
	local blockEq: string? = nil

	for _, line in lines do
		-- handle block comment continuation
		if inBlock then
			local eq = blockEq or ""
			local closingPattern = "%]" .. eq .. "%]"
			local before = string.match(line, "^(.-)" .. closingPattern)
			if before then
				before = stringext.trim(before)
				if before ~= "" then
					table.insert(pendingDoc, before)
				end
				inBlock = false
				blockEq = nil
			else
				local trimmed = stringext.trim(line)
				if trimmed ~= "" then
					table.insert(pendingDoc, trimmed)
				end
			end
			continue
		end

		-- detect block comment start
		local eq = string.match(line, blockCommentStartPattern)
		if eq then
			local after = string.match(line, "^%s*%-%-%[" .. eq .. "%[(.*)$")
			if after then
				after = stringext.trim(after)
				if after ~= "" then
					table.insert(pendingDoc, after)
				end
			end
			inBlock = true
			blockEq = eq
			continue
		end

		-- triple-dash comment
		local triple = string.match(line, tripleDashCommentPattern)
		if triple then
			local txt = stringext.trim(triple)
			if txt ~= "" then
				table.insert(pendingDoc, txt)
			end
			continue
		end

		-- property assignment
		local propName = string.match(line, `^{moduleAlias}%.([%w_]+)%s*=`)
		if propName then
			if #pendingDoc > 0 then
				docMap[propName] = table.concat(pendingDoc, "\n\n")
				pendingDoc = {}
			end
			continue
		end

		-- function declaration
		local fnName = string.match(line, `^function%s+{moduleAlias}%.([%w_]+)`)
		if fnName then
			if #pendingDoc > 0 then
				docMap[fnName] = table.concat(pendingDoc, "\n\n")
				pendingDoc = {}
			end
			continue
		end

		-- reset on real code
		if not string.match(line, whitespacePattern) then
			pendingDoc = {}
		end
	end

	return docMap
end

local function generateMarkdown(
	moduleName: string,
	definitions: { Definition },
	filePath: path.Pathlike,
	libraryPath: path.Pathlike,
	requireLibraryAlias: string
): string
	local libPathStr = tostring(libraryPath)
	local filePathStr = tostring(filePath)

	local relativePath = string.sub(filePathStr, #libPathStr + 2) -- gets the path relative to the require path (only relevant for subdirs like std/libs)
	relativePath = string.gsub(relativePath, "%.luau$", "")
	local requirePath = string.gsub(relativePath, "/init$", "") -- remove trailing /init and use the module dir name

	local lines = {
		`# {moduleName}`,
		"",
		"```luau",
		`local {moduleName} = require("@{requireLibraryAlias}/{requirePath}")`,
		"```",
		"",
	}

	-- LUAUFIX: we should not need to explicitly instantiate the type of `table.sort` here
	table.sort<<Definition>>(definitions, function(a, b)
		return a.name < b.name
	end)

	for _, def in definitions do
		table.insert(lines, `## {moduleName}.{def.name}\n`)

		-- Insert the documentation if it exists
		if def.doc then
			table.insert(lines, `{def.doc}\n`)
		end
		table.insert(lines, "```luau")
		table.insert(lines, def.signature)
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

local function parseModule(
	module: path.Pathlike,
	filePath: path.Pathlike
): { { name: string, signature: string, doc: string? } }
	local content = fs.readfiletostring(filePath)
	local docMap = collectDocs(content, module)

	local tp = luau.typeofmodule(filePath)
	if not tp or not tp.head or #tp.head == 0 then
		return {}
	end

	local moduleType = tp.head[1]
	if moduleType.tag ~= "table" or not moduleType.properties then
		return {}
	end

	local moduleDefinitions = {}

	for name, prop in pairs(moduleType.properties) do
		if prop.read then
			print(`Processing definition: {module}.{name}`)
			local sig = typeprinter.renderType(prop.read)
			print(`Signature: {sig}`)
			table.insert(moduleDefinitions, {
				name = name,
				signature = sig,
				doc = docMap[name],
			})
		end
	end

	return moduleDefinitions
end

local function processDirectory(
	modulePath: path.Pathlike,
	documentationPath: path.Pathlike,
	libraryPath: path.Pathlike,
	requireLibraryAlias: string
)
	fs.createdirectory(documentationPath, { makeparents = true })

	local entries = fs.listdirectory(modulePath)

	for _, entry in entries do
		local entryPath = path.join(modulePath, entry.name)
		local docPath = path.join(documentationPath, entry.name)

		if entry.type == "dir" then
			fs.createdirectory(docPath, { makeparents = true })
			processDirectory(entryPath, docPath, libraryPath, requireLibraryAlias)
		elseif entry.type == "file" and string.find(entry.name, "%.luau$") then
			local moduleName = string.gsub(entry.name, "%.luau$", "")
			local isInit = moduleName == "init"
			if isInit then
				moduleName = string.match(tostring(modulePath), "([^/\\]+)$") or moduleName
			end

			-- Use index.md for init.luau files, otherwise use moduleName.md
			local docFileName = if isInit then "index.md" else moduleName .. ".md"
			local documentationFilePath = path.join(documentationPath, docFileName)

			print(`Processing {moduleName}...`)

			local moduleAlias = if requireLibraryAlias == "std"
				then STDLIB_MODULE_ALIASES[moduleName] or moduleName
				else moduleName

			local definitions = parseModule(moduleAlias, entryPath)
			local markdown = generateMarkdown(moduleName, definitions, entryPath, libraryPath, requireLibraryAlias)

			fs.writestringtofile(documentationFilePath, markdown)

			print(`Generated {tostring(documentationFilePath)}`)
		end
	end
end

type Module = { name: string, isDir: boolean }

-- Helper to generate index with table of children
local function generateLibraryIndex(title: string, alias: string, modulePath: path.Pathlike): string
	local entries = fs.listdirectory(modulePath)
	local modules: { Module } = {}

	for _, entry in entries do
		local name = entry.name
		if entry.type == "dir" then
			-- Check if it has an init.luau (is a module)
			local initPath = path.join(modulePath, name, "init.luau")
			if fs.exists(initPath) then
				table.insert(modules, { name = name, isDir = true })
			end
		elseif entry.type == "file" and string.match(name, "%.luau$") then
			local modName = string.gsub(name, "%.luau$", "")
			if modName ~= "init" then
				table.insert(modules, { name = modName, isDir = false })
			end
		end
	end

	-- LUAUFIX: we should not need to explicitly instantiate the type of `table.sort`
	table.sort<<Module>>(modules, function(a, b)
		return a.name < b.name
	end)

	local lines = {
		`# {title}`,
		"",
		"| Module | Require |",
		"| ------ | ------- |",
	}

	for _, mod in modules do
		local link = if mod.isDir then `./{mod.name}/` else `./{mod.name}`
		table.insert(lines, `| [{mod.name}]({link}) | \`require("@{alias}/{mod.name}")\` |`)
	end

	table.insert(lines, "")
	return table.concat(lines, "\n")
end

local function generateAllDocs(outputDir: path.Path, modulePaths: { string }): ()
	-- Create top-level reference index page
	local referenceBasePath = path.join(outputDir, "reference")
	fs.createdirectory(referenceBasePath, { makeparents = true })

	-- Generate reference index with frontmatter for sidebar ordering
	local referenceIndex = [[---
order: 3
---

# Reference

API reference documentation for Lute's built-in libraries.
]]

	-- Generate docs for each specified module path
	for _, modulePath in modulePaths do
		local modulePathObj = path.parse(modulePath)
		local absModulePath = if path.isabsolute(modulePathObj)
			then modulePathObj
			else path.resolve(process.cwd(), modulePathObj)

		-- Explicitly match the aliases for lute and std, otherwise use the last part of the path as the alias
		local libraryAlias = absModulePath.parts[#absModulePath.parts - 1]
		if string.match(tostring(absModulePath), "/lute/std/libs") then
			libraryAlias = "std"
		elseif string.match(tostring(absModulePath), "/definitions") then
			libraryAlias = "lute"
		end

		local documentationPath = path.join(referenceBasePath, libraryAlias)
		processDirectory(absModulePath, documentationPath, absModulePath, libraryAlias)

		-- Generate module index with table of children
		local moduleIndex = generateLibraryIndex(libraryAlias, libraryAlias, absModulePath)
		fs.writestringtofile(path.join(documentationPath, "index.md"), moduleIndex)

		-- Add to the reference index with the correct alias
		referenceIndex ..= "\n\n- [" .. libraryAlias .. "](./" .. libraryAlias .. "/index.md)"

		-- Add the existing hard-coded info for lute and std
		if libraryAlias == "lute" then
			referenceIndex ..= " - Core runtime library (`@lute/*`)"
		elseif libraryAlias == "std" then
			referenceIndex ..= " - Standard library modules (`@std/*`)"
		end
	end

	fs.writestringtofile(path.join(referenceBasePath, "index.md"), referenceIndex)
end

local function main(...: string)
	local args = cli.parser()

	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	args:add(
		"output",
		"option",
		{ help = "Output directory for generated docs", default = tostring(DEFAULT_OUTPUT_DIR), aliases = { "o" } }
	)

	args:parse({ ... })

	if args:has("help") then
		printHelp()
		return
	end

	local outputDir = path.parse(args:get("output") or tostring(DEFAULT_OUTPUT_DIR))
	if not path.isabsolute(outputDir) then
		outputDir = path.resolve(process.cwd(), outputDir)
	end

	local modulePaths = args:forwarded()
	assert(
		modulePaths ~= nil and #modulePaths > 0,
		"Error: No module paths specified.\n\n" .. USAGE .. "\n\nUse --help for more information."
	)

	print("Generating documentation...")
	generateAllDocs(outputDir, modulePaths)
	print("Documentation generation complete! Files written to: ", tostring(outputDir))
end

main(...)
