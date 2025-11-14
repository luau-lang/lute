local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")
local stringext = require("@std/stringext")

-- extractPropertySignature:
-- module: string
-- line: string (current line)
-- pendingDoc: {string} (accumulated doc lines so far)
-- inBlock: boolean (are we currently inside a block comment?)
-- blockEq: string? (the "=" sequence used for block comment delimiting, e.g. "=" for --[=[  ; nil when not inside)
--
-- returns: name?, signature?, doc?, newPendingDoc, newInBlock, newBlockEq
local function extractPropertySignature(
	module: string,
	line: string,
	pendingDoc: { string },
	inBlock: boolean,
	blockEq: string?
): (string?, string?, string?, { string }, boolean, string?)
	local name, signature, doc = nil, nil, nil

	-- 1) If we're *not* in a block, detect block start that may include = signs:
	if not inBlock then
		local eq = string.match(line, "^%s*%-%-%[(=*)%[")
		if eq ~= nil then
			-- start of block comment, capture any text after the opening on the same line
			inBlock = true
			blockEq = eq -- remember the = count for closing pattern

			-- capture part after the opening delimiter, if any
			local after = string.match(line, "^%s*%-%-%[" .. eq .. "%[(.*)$")
			if after then
				after = stringext.trim(after)
				if after ~= "" then
					table.insert(pendingDoc, after)
				end
			end

			-- nothing else to do this line
			return nil, nil, nil, pendingDoc, inBlock, blockEq
		end
	end

	-- 2) If we're inside a block, accumulate until we find the matching close
	if inBlock then
		local eq = blockEq or ""
		-- find the closing pattern "]]", or "]=]" etc. that matches eq
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

		return nil, nil, nil, pendingDoc, inBlock, blockEq
	end

	-- 3) Single-line comment? (-- or ---)
	local single = string.match(line, "^%s*%-%-%-?%s?(.*)$")
	if single then
		local txt = stringext.trim(single)
		if txt ~= "" then
			table.insert(pendingDoc, txt)
		end
		return nil, nil, nil, pendingDoc, inBlock, blockEq
	end

	-- 4) Try property declaration: module.name = ... :: type
	local propName, propType = string.match(line, `^{module}%.([%w_]+)%s*=%s*.-::%s*(.+)$`)
	if propName and propType then
		name = propName
		signature = propType
		doc = (#pendingDoc > 0) and table.concat(pendingDoc, "\n\n") or nil
		pendingDoc = {}
		return name, signature, doc, pendingDoc, inBlock, blockEq
	end

	-- 5) Try function declaration: function module.name(params): return
	local fullName, params, _colon, returnType = string.match(line, `^function%s+{module}%.(.-)(%b())(:?)%s*(.*)$`)
	if fullName then
		fullName = string.match(fullName, "^(.*)%b<>$") or fullName
		returnType = (returnType == "") and "()" or returnType
		name = fullName
		signature = `{params} -> {returnType}`
		doc = (#pendingDoc > 0) and table.concat(pendingDoc, "\n\n") or nil
		pendingDoc = {}
		return name, signature, doc, pendingDoc, inBlock, blockEq
	end

	-- 6) If we reach here and there's any non-whitespace, reset pendingDoc to clear old comments
	if not string.match(line, "^%s*$") then
		pendingDoc = {}
	end

	-- nothing found
	return nil, nil, nil, pendingDoc, inBlock, blockEq
end

-- docs for definitions/*.luau --

local function parseDefinitionFile(module: path.pathlike, filePath: path.pathlike)
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")

	local defs = {}
	local pendingDoc = {}
	local inBlock = false

	for _, line in ipairs(lines) do
		local name, sig, doc
		name, sig, doc, pendingDoc, inBlock = extractPropertySignature(tostring(module), line, pendingDoc, inBlock)

		if name and sig then
			table.insert(defs, {
				name = name,
				signature = sig,
				doc = doc,
			})
		end
	end

	return defs
end

local function generateDefinitionsMarkdown(
	moduleName: string,
	definitions: { { name: string, signature: string, doc: string? } }
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

local function processDefinitionsDir(definitionsPath: path.pathlike, referencePath: path.pathlike)
	fs.createdirectory(referencePath, { makeparents = true })

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

local function parseStdlibFile(module: path.pathlike, filePath: path.pathlike)
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")

	local defs = {}
	local pendingDoc = {}
	local inBlock = false

	local mod = STDLIB_MODULE_ALIASES[tostring(module)] or tostring(module)

	for _, line in ipairs(lines) do
		local name, sig, doc
		name, sig, doc, pendingDoc, inBlock = extractPropertySignature(mod, line, pendingDoc, inBlock)

		if name and sig then
			table.insert(defs, {
				name = name,
				signature = sig,
				doc = doc,
			})
		end
	end

	return defs
end

local function generateStdLibMarkdown(
	moduleName: string,
	definitions: { { name: string, signature: string, doc: string? } },
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

local function processStdlibDir(sourceDir: path.pathlike, referenceDir: path.pathlike)
	fs.createdirectory(referenceDir, { makeparents = true })

	local entries = fs.listdir(sourceDir)

	for _, entry in entries do
		local sourcePath = path.join(sourceDir, entry.name)
		local referencePath = path.join(referenceDir, entry.name)

		if entry.type == "dir" then
			fs.createdirectory(referencePath, { makeparents = true })
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
