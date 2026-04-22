local cli = require("@batteries/cli")
local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")
local stringext = require("@std/stringext")

local USAGE = "Usage: lute doc [OPTIONS] [...MODULE_PATHS]"
local DEFAULT_OUTPUT_DIR = path.resolve(process.cwd(), "docs")

local STDLIB_MODULE_ALIASES = {
	assert = "assertions",
	fs = "fslib",
	io = "iolib",
	process = "processlib",
	path = "pathlib",
	system = "systemlib",
	trivia = "retrieverLib",
	visitor = "visitorlib",
	query = "queryLib",
	printer = "printerLib",
	failure = "failures",
}

local tripleDashCommentPattern = "^%s*%-%-%-%s?(.*)$"
local blockCommentStartPattern = "^%s*%-%-%[(=+)%["
local whitespacePattern = "^%s*$"
local exportTypePattern = "^%s*export%s+type%s+([%w_]+)%s*=(.*)$"

type PropertySignature = {
	name: string?,
	signature: string?,
	doc: string?,
	isType: boolean?,
	pendingDoc: { string },
	inBlock: boolean,
	blockEq: string?,
	-- multiline export type accumulation state
	inTypeDef: boolean?,
	typeDefName: string?,
	typeDefLines: { string }?,
	typeDefDepth: number?,
	typeDefDoc: { string }?,
}

type Mapping = {
	[string]: { alias: string, destination: string },
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

-- extractPropertySignature: (this function runs on one line at a time so we need to keep some states for block comments)
-- module (module name)
-- line (current line)
-- pendingDoc (accumulated doc lines so far)
-- inBlock (are we currently inside a block comment?)
-- blockEq (the "=" sequence used for block comment delimiting, e.g. "=" for --[=[  ; nil when not inside)
-- inTypeDef (are we currently accumulating a multiline export type?)
-- typeDefName (the name of the type being accumulated)
-- typeDefLines (accumulated lines of the type definition)
-- typeDefDepth (current brace depth inside the type)
-- typeDefDoc (saved pendingDoc to attach once the type is complete)
local function extractPropertySignature(
	module: string,
	line: string,
	pendingDoc: { string },
	inBlock: boolean,
	blockEq: string?,
	inTypeDef: boolean?,
	typeDefName: string?,
	typeDefLines: { string }?,
	typeDefDepth: number?,
	typeDefDoc: { string }?
): PropertySignature
	-- 1) If we're accumulating a multiline export type, keep collecting until braces balance
	if inTypeDef then
		local tLines = typeDefLines or {}
		local depth = typeDefDepth or 0
		local name = typeDefName or ""
		local savedDoc = typeDefDoc or {}

		table.insert(tLines, line)

		for char in string.gmatch(line, ".") do
			if char == "{" then
				depth += 1
			elseif char == "}" then
				depth -= 1
			end
		end

		if depth <= 0 then
			return {
				name = name,
				signature = table.concat(tLines, "\n"),
				doc = if #savedDoc > 0 then table.concat(savedDoc, "\n\n") else nil,
				isType = true,
				pendingDoc = {},
				inBlock = inBlock,
				blockEq = blockEq,
				inTypeDef = false,
				typeDefName = nil,
				typeDefLines = {},
				typeDefDepth = 0,
				typeDefDoc = nil,
			}
		else
			return {
				pendingDoc = pendingDoc,
				inBlock = inBlock,
				blockEq = blockEq,
				inTypeDef = true,
				typeDefName = name,
				typeDefLines = tLines,
				typeDefDepth = depth,
				typeDefDoc = savedDoc,
			}
		end
	end

	-- 2) If we're *not* in a block, detect block start that may include = signs:
	if not inBlock then
		local eq = string.match(line, blockCommentStartPattern)
		if eq ~= nil then
			-- start of block comment, capture part after the opening delimiter, if any
			local after = string.match(line, "^%s*%-%-%[" .. eq .. "%[(.*)$")
			if after then
				after = stringext.trim(after)
				if after ~= "" then
					table.insert(pendingDoc, after)
				end
			end

			return {
				pendingDoc = pendingDoc,
				inBlock = true,
				blockEq = eq, -- remember the = count for closing pattern
			}
		end
	end

	-- 3) If we're inside a block, accumulate until we find the matching close
	if inBlock then
		local eq = blockEq or ""
		-- find the closing pattern "]=]" that matches the # of "=" used in opening
		local closingPattern = "%]" .. eq .. "%]"
		local before = string.match(line, "^(.-)" .. closingPattern)
		if before then
			-- closing found on this line
			before = stringext.trim(before)
			if before ~= "" then
				table.insert(pendingDoc, before)
			end

			-- there might be trailing comment markers like "]]" on the same line;
			-- we've already captured inner content, so we just exit block mode.
			inBlock = false
			blockEq = nil
		else
			-- still inside block: append whole line (trimmed)
			local trimmed = stringext.trim(line)
			if trimmed ~= "" then
				table.insert(pendingDoc, trimmed)
			end
		end

		return {
			pendingDoc = pendingDoc,
			inBlock = inBlock,
			blockEq = blockEq,
		}
	end

	-- 4) Triple dash comment? (---)
	local triple = string.match(line, tripleDashCommentPattern)
	if triple then
		local txt = stringext.trim(triple)
		if txt ~= "" then
			table.insert(pendingDoc, txt)
		end
		return {
			pendingDoc = pendingDoc,
			inBlock = inBlock,
			blockEq = blockEq,
		}
	end

	-- 5) Export type declaration (exported types only; unexported types are internal)
	local typeName, typeRest = string.match(line, exportTypePattern)
	if typeName then
		local trimmedRest = stringext.trim(typeRest)

		local depth = 0
		for char in string.gmatch(trimmedRest, ".") do
			if char == "{" then
				depth += 1
			elseif char == "}" then
				depth -= 1
			end
		end

		local firstTypeLine = `type {typeName} = {trimmedRest}`

		if depth <= 0 then
			-- Single-line or already-balanced type
			return {
				name = typeName,
				signature = firstTypeLine,
				doc = if #pendingDoc > 0 then table.concat(pendingDoc, "\n\n") else nil,
				isType = true,
				pendingDoc = {},
				inBlock = inBlock,
				blockEq = blockEq,
				inTypeDef = false,
				typeDefLines = {},
				typeDefDepth = 0,
			}
		else
			-- Multiline type — begin accumulation, save pending doc for later
			return {
				pendingDoc = {},
				inBlock = inBlock,
				blockEq = blockEq,
				inTypeDef = true,
				typeDefName = typeName,
				typeDefLines = { firstTypeLine },
				typeDefDepth = depth,
				typeDefDoc = pendingDoc,
			}
		end
	end

	-- 6) Match property declarations like: process.env = {} :: { [string]: string }
	local propName, propType = string.match(line, `^{module}%.([%w_]+)%s*=%s*.-::%s*(.+)$`)
	if propName and propType then
		return {
			name = propName,
			signature = propType,
			doc = if #pendingDoc > 0 then table.concat(pendingDoc, "\n\n") else nil,
			pendingDoc = {},
			inBlock = inBlock,
			blockEq = blockEq,
		}
	end

	-- 7) Match function declarations like: function crypto.password.hash(password: string): buffer
	local fullName, params, _return, returnType = string.match(line, `^function%s+{module}%.(.-)(%b())(:?)%s*(.*)$`)
	if fullName then
		fullName = string.match(fullName, "^(.*)%b<>$") or fullName
		returnType = if returnType == "" then "()" else returnType

		return {
			name = fullName,
			signature = `{params} -> {returnType}`,
			doc = if #pendingDoc > 0 then table.concat(pendingDoc, "\n\n") else nil,
			pendingDoc = {},
			inBlock = inBlock,
			blockEq = blockEq,
		}
	end

	-- 8) If we reach here and there's any non-whitespace (i.e., code), reset pendingDoc to clear old comments
	if not string.match(line, whitespacePattern) then
		pendingDoc = {}
	end

	-- nothing found on this line
	return {
		pendingDoc = pendingDoc,
		inBlock = inBlock,
		blockEq = blockEq,
	}
end

type Definition = { name: string, signature: string, doc: string? }
type TypeDefinition = { name: string, signature: string, doc: string? }

type ParseResult = {
	definitions: { Definition },
	typeDefinitions: { TypeDefinition },
}

local function parseModule(module: path.Pathlike, filePath: path.Pathlike): ParseResult
	local content = fs.readFileToString(filePath)
	local lines = string.split(content, "\n")

	local moduleDefinitions: { Definition } = {}
	local typeDefinitions: { TypeDefinition } = {}
	local pendingDoc: { string } = {}
	local inBlock = false
	local blockEq = nil
	local inTypeDef = false
	local typeDefName = nil
	local typeDefLines: { string } = {}
	local typeDefDepth = 0
	local typeDefDoc: { string } = {}

	for _, line in lines do
		local ps = extractPropertySignature(
			tostring(module),
			line,
			pendingDoc,
			inBlock,
			blockEq,
			inTypeDef,
			typeDefName,
			typeDefLines,
			typeDefDepth,
			typeDefDoc
		)

		-- update state carried across lines
		pendingDoc = ps.pendingDoc
		inBlock = ps.inBlock
		blockEq = ps.blockEq
		inTypeDef = ps.inTypeDef or false
		typeDefName = ps.typeDefName
		typeDefLines = ps.typeDefLines or {}
		typeDefDepth = ps.typeDefDepth or 0
		typeDefDoc = ps.typeDefDoc or {}

		if ps.name and ps.signature then
			if ps.isType then
				table.insert(typeDefinitions, {
					name = ps.name,
					signature = ps.signature,
					doc = ps.doc,
				})
			else
				table.insert(moduleDefinitions, {
					name = ps.name,
					signature = ps.signature,
					doc = ps.doc,
				})
			end
		end
	end

	return {
		definitions = moduleDefinitions,
		typeDefinitions = typeDefinitions,
	}
end

-- Returns the first line of a doc string, for use in summary tables.
local function firstLine(doc: string?): string
	if not doc then
		return ""
	end
	return string.match(doc, "^([^\n]+)") or doc
end

-- Generates a GitHub-compatible anchor from a heading string.
local function toAnchor(text: string): string
	text = string.lower(text)
	text = string.gsub(text, "[^%w%-]", "")
	return text
end

local function generateMarkdown(
	moduleName: string,
	definitions: { Definition },
	typeDefinitions: { TypeDefinition },
	filePath: path.Pathlike,
	libraryPath: path.Pathlike,
	requireLibraryAlias: string
): string
	local libPathStr = tostring(libraryPath)
	local filePathStr = tostring(filePath)

	local relativePath = string.sub(filePathStr, #libPathStr + 2) -- gets the path relative to the require path (only relevant for subdirs like std/libs)
	relativePath = string.gsub(relativePath, "%.luau$", "")
	local requirePath = string.gsub(relativePath, "/init$", "") -- remove trailing /init and use the module dir name

	-- LUAUFIX: we should not need to explicitly instantiate the type of `table.sort` here
	table.sort<<Definition>>(definitions, function(a, b)
		return a.name < b.name
	end)
	table.sort<<TypeDefinition>>(typeDefinitions, function(a, b)
		return a.name < b.name
	end)

	local lines = {
		`# {moduleName}`,
		"",
		"```luau",
		`local {moduleName} = require("@{requireLibraryAlias}/{requirePath}")`,
		"```",
		"",
	}

	-- Summary table
	if #definitions > 0 or #typeDefinitions > 0 then
		table.insert(lines, "## Summary")
		table.insert(lines, "")
		table.insert(lines, "| Entry | Description |")
		table.insert(lines, "| :--- | :--- |")

		for _, typeDef in typeDefinitions do
			local anchor = toAnchor(typeDef.name)
			table.insert(lines, `| [{typeDef.name}](#{anchor}) | {firstLine(typeDef.doc)} |`)
		end

		for _, def in definitions do
			local anchor = toAnchor(`{moduleName}.{def.name}`)
			table.insert(lines, `| [{def.name}](#{anchor}) | {firstLine(def.doc)} |`)
		end

		table.insert(lines, "")
		table.insert(lines, "---")
		table.insert(lines, "")
	end

	-- Types section
	if #typeDefinitions > 0 then
		table.insert(lines, "## Types")
		table.insert(lines, "")

		for _, typeDef in typeDefinitions do
			table.insert(lines, `### {typeDef.name}`)
			table.insert(lines, "")
			if typeDef.doc then
				table.insert(lines, typeDef.doc)
				table.insert(lines, "")
			end
			table.insert(lines, "```luau")
			table.insert(lines, typeDef.signature)
			table.insert(lines, "```")
			table.insert(lines, "")
			table.insert(lines, "---")
			table.insert(lines, "")
		end
	end

	-- Functions and Properties section
	if #definitions > 0 then
		table.insert(lines, "## Functions and Properties")
		table.insert(lines, "")

		for _, def in definitions do
			table.insert(lines, `### {moduleName}.{def.name}`)
			table.insert(lines, "")
			if def.doc then
				table.insert(lines, def.doc)
				table.insert(lines, "")
			end
			table.insert(lines, "```luau")
			table.insert(lines, def.signature)
			table.insert(lines, "```")
			table.insert(lines, "")
			table.insert(lines, "---")
			table.insert(lines, "")
		end
	end

	return table.concat(lines, "\n")
end

local function processDirectory(
	modulePath: path.Pathlike,
	documentationPath: path.Pathlike,
	libraryPath: path.Pathlike,
	requireLibraryAlias: string
)
	fs.createDirectory(documentationPath, { makeParents = true })

	local entries = fs.listDirectory(modulePath)

	for _, entry in entries do
		local entryPath = path.join(modulePath, entry.name)
		local docPath = path.join(documentationPath, entry.name)

		if entry.type == "dir" then
			fs.createDirectory(docPath, { makeParents = true })
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

			local result = parseModule(moduleAlias, entryPath)
			local markdown = generateMarkdown(
				moduleName,
				result.definitions,
				result.typeDefinitions,
				entryPath,
				libraryPath,
				requireLibraryAlias
			)

			fs.writeStringToFile(documentationFilePath, markdown)

			print(`Generated {tostring(documentationFilePath)}`)
		end
	end
end

type Module = { name: string, isDir: boolean }

-- Helper to generate index with table of children
local function generateLibraryIndex(title: string, alias: string, modulePath: path.Pathlike): string
	local entries = fs.listDirectory(modulePath)
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

local function generateDocsFromMapping(mapping: Mapping): ()
	for sourcePath, info in pairs(mapping) do
		local absSourcePath = if path.isAbsolute(sourcePath)
			then path.parse(sourcePath)
			else path.resolve(process.cwd(), sourcePath)

		if not fs.exists(absSourcePath) then
			print(`Warning: Source path does not exist: {tostring(absSourcePath)}`)
			continue
		end

		local destinationPath = if path.isAbsolute(info.destination)
			then path.parse(info.destination)
			else path.resolve(process.cwd(), info.destination)
		local alias = info.alias

		print(
			`Generating docs for {tostring(absSourcePath)} with alias @{alias} to destination {tostring(destinationPath)}...`
		)
		processDirectory(absSourcePath, destinationPath, absSourcePath, alias)
		print(`Completed generating docs for {tostring(absSourcePath)}.`)
	end
end

local function generateAllDocs(outputDir: path.Path, modulePaths: { string }): ()
	-- Create top-level reference index page
	local referenceBasePath = path.join(outputDir, "reference")
	fs.createDirectory(referenceBasePath, { makeParents = true })

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
		local absModulePath = if path.isAbsolute(modulePathObj)
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
		fs.writeStringToFile(path.join(documentationPath, "index.md"), moduleIndex)

		-- Add to the reference index with the correct alias
		referenceIndex ..= "\n\n- [" .. libraryAlias .. "](./" .. libraryAlias .. "/index.md)"

		-- Add the existing hard-coded info for lute and std
		if libraryAlias == "lute" then
			referenceIndex ..= " - Core runtime library (`@lute/*`)"
		elseif libraryAlias == "std" then
			referenceIndex ..= " - Standard library modules (`@std/*`)"
		end
	end

	fs.writeStringToFile(path.join(referenceBasePath, "index.md"), referenceIndex)
end

local function main(...: string)
	local args = cli.parser()

	args:add("help", "flag", { help = "Show help message", aliases = { "h" } })
	args:add("mapping", "option", {
		help = "Custom mapping for generating documentation",
		aliases = { "m" },
	})
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
	if not path.isAbsolute(outputDir) then
		outputDir = path.resolve(process.cwd(), outputDir)
	end

	local mapFile = args:get("mapping")
	if mapFile then
		local mapPath = path.join(process.cwd(), mapFile)
		local mod = luau.loadModule(mapPath) :: Mapping
		print(`Using custom mapping from file {tostring(mapPath)}`)
		generateDocsFromMapping(mod)
		return
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
