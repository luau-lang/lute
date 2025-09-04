local fs = require("@lute/fs")
local process = require("@lute/process")

local function projectRelative(...)
	local cwd = process.cwd()
	local pathSep = if string.find(string.lower(require("@lute/system").os), "windows") then "\\" else "/"
	return table.concat({ cwd, "..", ... }, pathSep)
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

local function generateMarkdown(moduleName: string, definitions: { { name: string, signature: string } }): string
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
		table.insert(lines, "## " .. def.name)
		table.insert(lines, "```luau")
		table.insert(lines, def.signature)
		table.insert(lines, "```")
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

local definitionsPath = projectRelative("definitions")
local referencePath = projectRelative("docs", "reference")

pcall(fs.mkdir, referencePath)

local definitionFiles = fs.listdir(definitionsPath)

for _, file in definitionFiles do
	if file.type == "file" and string.find(file.name, "%.luau$") then
		local moduleName = string.gsub(file.name, "%.luau$", "")
		local definitionFilePath = definitionsPath .. "/" .. file.name
		local referenceFilePath = referencePath .. "/" .. moduleName .. ".md"

		print("Processing " .. moduleName .. "...")

		local definitions = parseDefinitionFile(moduleName, definitionFilePath)
		local markdown = generateMarkdown(moduleName, definitions)

		fs.writestringtofile(referenceFilePath, markdown)

		print("Generated " .. referenceFilePath)
	end
end

print("Reference documentation generation complete!")
