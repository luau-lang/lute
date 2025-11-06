local fs = require("@std/fs")
local process = require("@std/process")
local system = require("@std/system")

local function projectRelative(...)
	local cwd = process.cwd()
	local sep = if string.find(string.lower(system.os), "windows") then "\\" else "/"
	return table.concat({ tostring(cwd), ... }, sep)
end

local function extractPropertySignature(module: string, line: string): (string?, string?)
	-- Match property declarations like: process.env = {} :: { [string]: string }
	local propName, propType = string.match(line, `^{module}%.([%w_]+)%s*=%s*.-::%s*(.+)$`)
	if propName and propType then
		return propName, propType
	end

	-- Match function declarations like: function crypto.password.hash(password: string): buffer
	local fullName, params, _return, returnType = string.match(line, `^function%s+{module}%.(.-)(%b())(:?)%s*(.*)$`)
	if fullName then
		fullName = string.match(fullName, "^(.*)%b<>$") or fullName
		returnType = if returnType == "" then "()" else returnType
		local signature = `{params} -> {returnType}`
		return fullName, signature
	end

	return nil, nil
end

-- docs for definitions/*.luau --

local function parseDefinitionFile(module: string, filePath: string): { { name: string, signature: string } }
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")
	local definitions = {}

	for _, line in lines do
		local name, signature = extractPropertySignature(module, line)

		if name and signature then
			table.insert(definitions, {
				name = name,
				signature = signature,
			})
		end
	end

	return definitions
end

local function generateDefinitionsMarkdown(
	moduleName: string,
	definitions: { { name: string, signature: string } }
): string
	local lines = {
		"# " .. moduleName,
		"",
		"```luau",
		"local " .. moduleName .. ' = require("@lute/' .. moduleName .. '")',
		"```",
		"",
	}

	table.sort(definitions, function(a, b)
		return a.name < b.name
	end)

	for _, def in definitions do
		table.insert(lines, `## {moduleName}.{def.name}`)
		table.insert(lines, "```luau")
		table.insert(lines, def.signature)
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

local function processDefinitionsDir(definitionsPath: string, referencePath: string)
	pcall(fs.createdirectory, referencePath)

	local definitionFiles = fs.listdir(definitionsPath)

	for _, file in definitionFiles do
		if file.type == "file" and string.find(file.name, "%.luau$") then
			local moduleName = string.gsub(file.name, "%.luau$", "")
			local definitionFilePath = definitionsPath .. "/" .. file.name
			local referenceFilePath = referencePath .. "/" .. moduleName .. ".md"

			print("Processing " .. moduleName .. "...")

			local definitions = parseDefinitionFile(moduleName, definitionFilePath)
			local markdown = generateDefinitionsMarkdown(moduleName, definitions)

			fs.writestringtofile(referenceFilePath, markdown)

			print("Generated " .. referenceFilePath)
		end
	end
end

-- docs for lute/std/libs/*.luau --

local STDLIB_MODULE_ALIASES = {
	assert = "assertions",
	fs = "fslib",
	io = "iolib",
	process = "processlib",
	task = "tasklib",
	path = "pathlib",
	system = "systemlib",
}

local function parseStdlibFile(module: string, filePath: string): { { name: string, signature: string } }
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")
	local stdlibDefinitions = {}

	for _, line in lines do
		local mod = STDLIB_MODULE_ALIASES[module] or module

		local name, signature = extractPropertySignature(mod, line)

		if name and signature then
			table.insert(stdlibDefinitions, {
				name = name,
				signature = signature,
			})
		end
	end

	return stdlibDefinitions
end

local function generateStdLibMarkdown(
	moduleName: string,
	definitions: { { name: string, signature: string } },
	stdlibFilePath: string
): string
	local referencePath = projectRelative("lute/std/libs/")
	local relativePath = string.sub(stdlibFilePath, #referencePath + 1)
	relativePath = string.gsub(relativePath, "%.luau$", "")
	local modulePath = string.gsub(relativePath, "/init$", "")

	local lines = {
		"# " .. moduleName,
		"",
		"```luau",
		"local " .. moduleName .. ' = require("@std/' .. modulePath .. '")',
		"```",
		"",
	}

	table.sort(definitions, function(a, b)
		return a.name < b.name
	end)

	for _, def in definitions do
		table.insert(lines, `## {moduleName}.{def.name}`)
		table.insert(lines, "```luau")
		table.insert(lines, def.signature)
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

local function processStdlibDir(sourceDir: string, referenceDir: string)
	pcall(fs.createdirectory, referenceDir)

	local entries = fs.listdir(sourceDir)

	for _, entry in entries do
		local sourcePath = sourceDir .. "/" .. entry.name
		local referencePath = referenceDir .. "/" .. entry.name

		if entry.type == "dir" then
			pcall(fs.createdirectory, referencePath)
			processStdlibDir(sourcePath, referencePath)
		elseif entry.type == "file" and string.find(entry.name, "%.luau$") then
			local moduleName = string.gsub(entry.name, "%.luau$", "")
			if moduleName == "init" then
				moduleName = string.match(sourceDir, "([^/\\]+)$") or moduleName
			end

			local referenceFilePath = referenceDir .. "/" .. moduleName .. ".md"

			print("Processing " .. moduleName .. "...")

			local stdlibDefinitions = parseStdlibFile(moduleName, sourcePath)
			local markdown = generateStdLibMarkdown(moduleName, stdlibDefinitions, sourcePath)

			fs.writestringtofile(referenceFilePath, markdown)

			print("Generated " .. referenceFilePath)
		end
	end
end

local definitionsPath = projectRelative("definitions")
local referencePath = projectRelative("docs", "reference", "definitions")
processDefinitionsDir(definitionsPath, referencePath)

local stdlibPath = projectRelative("lute/std/libs")
local stdlibReferencePath = projectRelative("docs", "reference", "std")
processStdlibDir(stdlibPath, stdlibReferencePath)

print("Reference documentation generation complete!")
