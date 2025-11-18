local fs = require("@std/fs")
local process = require("@std/process")
local path = require("@std/path")
local stringext = require("@std/stringext")

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

local tripleDashCommentPattern = "^%s*%-%-%-%s?(.*)$"
local blockCommentStartPattern = "^%s*%-%-%[(=+)%["
local whitespacePattern = "^%s*$"

type PropertySignature = {
	name: string?,
	signature: string?,
	doc: string?,
	pendingDoc: { string },
	inBlock: boolean,
	blockEq: string?,
}

-- extractPropertySignature: (this function runs on one line at a time so we need to keep some states for block comments)
-- module (module name)
-- line (current line)
-- pendingDoc (accumulated doc lines so far)
-- inBlock (are we currently inside a block comment?)
-- blockEq (the "=" sequence used for block comment delimiting, e.g. "=" for --[=[  ; nil when not inside)
local function extractPropertySignature(
	module: string,
	line: string,
	pendingDoc: { string },
	inBlock: boolean,
	blockEq: string?
): PropertySignature
	-- 1) If we're *not* in a block, detect block start that may include = signs:
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

	-- 2) If we're inside a block, accumulate until we find the matching close
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

	-- 3) Triple dash comment? (---)
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

	-- 4) Match property declarations like: process.env = {} :: { [string]: string }
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

	-- 5) Match function declarations like: function crypto.password.hash(password: string): buffer
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

	-- 6) If we reach here and there's any non-whitespace (i.e., code), reset pendingDoc to clear old comments
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

local function generateMarkdown(
	moduleName: string,
	definitions: { { name: string, signature: string, doc: string? } },
	filePath: path.pathlike,
	libraryPath: path.pathlike,
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

local function parseModule(
	module: path.pathlike,
	filePath: path.pathlike
): { { name: string, signature: string, doc: string? } }
	local content = fs.readfiletostring(filePath)
	local lines = string.split(content, "\n")

	local moduleDefinitions = {}
	local pendingDoc = {}
	local inBlock = false
	local blockEq = nil

	for _, line in lines do
		local ps = extractPropertySignature(tostring(module), line, pendingDoc, inBlock, blockEq)

		-- update state carried across lines
		pendingDoc = ps.pendingDoc
		inBlock = ps.inBlock
		blockEq = ps.blockEq

		if ps.name and ps.signature then
			table.insert(moduleDefinitions, {
				name = ps.name,
				signature = ps.signature,
				doc = ps.doc,
			})
		end
	end

	return moduleDefinitions
end

local function processDirectory(
	modulePath: path.pathlike,
	documentationPath: path.pathlike,
	libraryPath: path.pathlike,
	requireLibraryAlias: string
)
	fs.createdirectory(documentationPath, { makeparents = true })

	local entries = fs.listdir(modulePath)

	for _, entry in entries do
		local entryPath = path.join(modulePath, entry.name)
		local docPath = path.join(documentationPath, entry.name)

		if entry.type == "dir" then
			fs.createdirectory(docPath, { makeparents = true })
			processDirectory(entryPath, docPath, libraryPath, requireLibraryAlias)
		elseif entry.type == "file" and string.find(entry.name, "%.luau$") then
			local moduleName = string.gsub(entry.name, "%.luau$", "")
			if moduleName == "init" then
				moduleName = string.match(tostring(modulePath), "([^/\\]+)$") or moduleName
			end

			local documentationFilePath = path.join(documentationPath, moduleName .. ".md")

			print(`Processing {moduleName}...`)

			if requireLibraryAlias == "std" then
				moduleName = STDLIB_MODULE_ALIASES[moduleName] or moduleName
			end

			local definitions = parseModule(moduleName, entryPath)
			local markdown = generateMarkdown(moduleName, definitions, entryPath, libraryPath, requireLibraryAlias)

			fs.writestringtofile(documentationFilePath, markdown)

			print(`Generated {tostring(documentationFilePath)}`)
		end
	end
end

local definitionsPath = path.join(process.cwd(), "..", "definitions")
local referencePath = path.join(process.cwd(), "reference", "definitions")
processDirectory(definitionsPath, referencePath, definitionsPath, "lute")

local stdlibPath = path.join(process.cwd(), "..", "lute", "std", "libs")
local stdlibReferencePath = path.join(process.cwd(), "reference", "std")
processDirectory(stdlibPath, stdlibReferencePath, stdlibPath, "std")

-- Mock module in test/ for testing purposes

-- local testPath = path.join(process.cwd(), "test")
-- local testReferencePath = path.join(process.cwd(), "test")
-- processDirectory(testPath, testReferencePath, testPath, "test")

print("Reference documentation generation complete!")
