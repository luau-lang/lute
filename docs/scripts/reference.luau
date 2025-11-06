local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")

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

local function parseDefinitionFile(
	module: path.pathlike,
	filePath: path.pathlike
): { { name: string, signature: string } }
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")
	local definitions = {}

	for _, line in lines do
		local name, signature = extractPropertySignature(tostring(module), line)

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
		`# {moduleName}`,
		"",
		"```luau",
		`local {moduleName} = require("@lute/{moduleName}")`,
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

local function processDefinitionsDir(definitionsPath: path.pathlike, referencePath: path.pathlike)
	pcall(fs.createdirectory, referencePath)

	local definitionFiles = fs.listdir(definitionsPath)

	for _, file in definitionFiles do
		if file.type == "file" and string.find(file.name, "%.luau$") then
			local moduleName = string.gsub(file.name, "%.luau$", "")
			local definitionFilePath = path.join(definitionsPath, file.name)
			local referenceFilePath = path.join(referencePath, moduleName .. ".md")

			print(`Processing {moduleName}...`)

			local definitions = parseDefinitionFile(moduleName, definitionFilePath)
			local markdown = generateDefinitionsMarkdown(moduleName, definitions)

			fs.writestringtofile(referenceFilePath, markdown)

			print(`Generated {tostring(referenceFilePath)}`)
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

local function parseStdlibFile(module: path.pathlike, filePath: path.pathlike): { { name: string, signature: string } }
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")
	local stdlibDefinitions = {}

	for _, line in lines do
		local mod = STDLIB_MODULE_ALIASES[tostring(module)] or tostring(module)

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
	stdlibFilePath: path.pathlike
): string
	local referencePath = path.join(process.cwd(), "..", "lute", "std", "libs")

	local refPathStr = tostring(referencePath)
	local stdlibFilePathStr = tostring(stdlibFilePath)

	local relativePath = string.sub(stdlibFilePathStr, #refPathStr + 2) -- gets the path relative to std/libs for the require path
	relativePath = string.gsub(relativePath, "%.luau$", "")
	local requirePath = string.gsub(relativePath, "/init$", "")

	local lines = {
		`# {moduleName}`,
		"",
		"```luau",
		`local {moduleName} = require("@std/{requirePath}")`,
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

local function processStdlibDir(sourceDir: path.pathlike, referenceDir: path.pathlike)
	pcall(fs.createdirectory, referenceDir)

	local entries = fs.listdir(sourceDir)

	for _, entry in entries do
		local sourcePath = path.join(sourceDir, entry.name)
		local referencePath = path.join(referenceDir, entry.name)

		if entry.type == "dir" then
			pcall(fs.createdirectory, referencePath)
			processStdlibDir(sourcePath, referencePath)
		elseif entry.type == "file" and string.find(entry.name, "%.luau$") then
			local moduleName = string.gsub(entry.name, "%.luau$", "")
			if moduleName == "init" then
				moduleName = string.match(tostring(sourceDir), "([^/\\]+)$") or moduleName
			end

			local referenceFilePath = path.join(referenceDir, moduleName .. ".md")

			print(`Processing {moduleName}...`)

			local stdlibDefinitions = parseStdlibFile(moduleName, sourcePath)
			local markdown = generateStdLibMarkdown(moduleName, stdlibDefinitions, sourcePath)

			fs.writestringtofile(referenceFilePath, markdown)

			print(`Generated {tostring(referenceFilePath)}`)
		end
	end
end

local definitionsPath = path.join(process.cwd(), "..", "definitions")
local referencePath = path.join(process.cwd(), "reference", "definitions")
processDefinitionsDir(definitionsPath, referencePath)

local stdlibPath = path.join(process.cwd(), "..", "lute", "std", "libs")
local stdlibReferencePath = path.join(process.cwd(), "reference", "std")
processStdlibDir(stdlibPath, stdlibReferencePath)

print("Reference documentation generation complete!")
