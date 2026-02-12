local process = require("@lute/process")
local win32types = require("@self/types")
local pathinterface = require("./pathinterface")

export type pathkind = win32types.pathkind
export type path = win32types.path
export type pathlike = win32types.pathlike

local win32 = {}
win32.pathmt = {} :: pathinterface.pathinterface

function win32.basename(path: pathlike): string?
	path = if typeof(path) == "string" then win32.parse(path) else path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function win32.dirname(path: pathlike): string
	path = if typeof(path) == "string" then win32.parse(path) else path

	if #path.parts == 0 then
		return win32.format(path)
	else
		return win32.format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			kind = path.kind,
			drive = path.drive,
		})
	end
end

function win32.extname(path: pathlike): string
	path = if typeof(path) == "string" then win32.parse(path) else path

	if #path.parts == 0 then
		return ""
	end

	local filename = path.parts[#path.parts]

	if filename == "." or filename == ".." then
		return ""
	end

	local dotIndex, _ = filename:find("%.[^%.]*$")
	if dotIndex == nil or dotIndex == 1 then
		return ""
	end

	return filename:sub(dotIndex)
end

function win32.drive(path: pathlike): path
	path = if typeof(path) == "string" then win32.parse(path) else path

	if path.drive == nil then
		error("Path does not have a drive letter: " .. win32.format(path))
	end

	return setmetatable(
		{
			parts = {},
			kind = "absolute",
			drive = path.drive,
		} :: win32types.pathdata,
		win32.pathmt
	)
end

function win32.format(path: pathlike): string
	if typeof(path) == "string" then
		return path
	end

	if #path.parts == 0 then
		if path.kind == "unc" then
			return "\\\\"
		elseif path.drive ~= nil then
			return table.concat({ path.drive, ":", (if path.kind == "absolute" then "\\" else "") })
		else
			return "."
		end
	else
		local parts = table.concat(path.parts, "\\")
		if path.kind == "unc" then
			return "\\\\" .. parts
		elseif path.drive ~= nil then
			return table.concat({ path.drive, ":", (if path.kind == "absolute" then "\\" else ""), parts })
		else
			return parts
		end
	end
end

function win32.isabsolute(path: pathlike): boolean
	path = if typeof(path) == "string" then win32.parse(path) else path
	return path.kind ~= "relative"
end

-- In place extends path with addend
local function joinHelper(path: path, addend: pathlike): ()
	addend = if typeof(addend) == "string" then win32.parse(addend) else addend

	if addend.kind ~= "relative" then
		error(`Could not join {path.kind} path {win32.format(path)} and {addend.kind} path {win32.format(addend)}`)
	end

	local driveLettersIncompatible = path.drive ~= nil
		and addend.drive ~= nil
		and addend.drive:lower() ~= path.drive:lower()

	if driveLettersIncompatible then
		error(`Could not join paths with incompatible drive letters: {win32.format(path)} and {win32.format(addend)}`)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)

	if path.drive == nil and addend.drive ~= nil then
		path.drive = addend.drive
	end
end

function win32.join(...: pathlike): path
	local parts = { ... }
	if #parts == 0 then
		return setmetatable(
			{
				parts = {},
				kind = "relative",
				drive = nil,
			} :: win32types.pathdata, -- Cast needed because of table invariance
			win32.pathmt
		)
	end

	local path: path = if typeof(parts[1]) == "string"
		then win32.parse(parts[1])
		else setmetatable({
			parts = table.clone((parts[1] :: path).parts), -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			kind = (parts[1] :: path).kind, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			drive = (parts[1] :: path).drive, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
		}, win32.pathmt)

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

function win32.normalize(path: pathlike): path
	path = if typeof(path) == "string" then win32.parse(path) else path

	local newParts = {}
	for _, part in path.parts do
		if part == "" or part == "." then
			continue
		elseif part == ".." then
			if path.kind == "unc" or path.kind == "absolute" then
				if #newParts > 0 then -- if absolute, only pop if we're not at the root
					table.remove(newParts, #newParts)
				end
			else -- if a relative path, we keep .. prefixes
				if #newParts > 0 and newParts[#newParts] ~= ".." then
					table.remove(newParts, #newParts)
				else
					table.insert(newParts, "..")
				end
			end
		else
			table.insert(newParts, part)
		end
	end

	return setmetatable({
		parts = newParts,
		kind = path.kind,
		drive = path.drive,
	}, win32.pathmt)
end

function win32.parse(path: pathlike): path
	if typeof(path) == "table" then
		return setmetatable(path, win32.pathmt)
	end
	if typeof(path) ~= "string" then
		error("Expected string or path")
	end

	local kind: pathkind = "relative"
	local driveLetter = nil

	-- Check if path is absolute and if it's a unc path on Windows
	if string.sub(path, 1, 2) == "\\\\" then
		-- unc path
		kind = "unc"
	elseif string.match(path, "^%a:") ~= nil then
		driveLetter = string.sub(path, 1, 1)
		-- Windows: starts with drive letter + separator (C:\ or C:/)
		local sep = path:sub(3, 3)
		kind = if sep == "\\" or sep == "/" then "absolute" else "relative"
	end

	local parts = {}
	-- Windows supports mixed separators, so sub forward slashes for backslashes first
	path = path:gsub("/", "\\")

	if kind == "unc" then
		-- Strip out the leading \\ for unc paths
		parts = path:sub(3):split("\\")
	elseif kind == "absolute" then
		-- Strip out the drive letter, colon, and backslash (C:\)
		parts = path:sub(4):split("\\")
	elseif driveLetter ~= nil then
		-- Strip out the drive letter and colon (C:)
		parts = path:sub(3):split("\\")
	else
		parts = path:split("\\")
	end

	-- Filter out empty parts (can happen with leading/trailing separators)
	if #parts > 0 then
		if parts[#parts] == "" then
			table.remove(parts, #parts)
		end
		if #parts > 0 and parts[1] == "" then
			table.remove(parts, 1)
		end
	end

	return setmetatable({
		parts = parts,
		kind = kind,
		drive = driveLetter,
	}, win32.pathmt)
end

function win32.relative(from: pathlike, to: pathlike): path
	from = if typeof(from) == "string" then win32.parse(from) else from
	to = if typeof(to) == "string" then win32.parse(to) else to

	if from.kind ~= to.kind then
		error("Cannot compute relative path between different kinds of paths")
	end

	if from.drive ~= to.drive then
		error("Cannot compute relative path between different drives")
	end

	local commonPrefixLength = 0

	for i = 1, math.min(#from.parts, #to.parts) do
		if from.parts[i] ~= to.parts[i] then
			break
		end
		commonPrefixLength += 1
	end

	local relativeParts = {}

	if #from.parts > commonPrefixLength then
		for _ = commonPrefixLength + 1, #from.parts do
			table.insert(relativeParts, "..")
		end
	end

	if #to.parts > commonPrefixLength then
		for i = commonPrefixLength + 1, #to.parts do
			table.insert(relativeParts, to.parts[i])
		end
	end

	return setmetatable({
		parts = relativeParts,
		kind = "relative",
		drive = nil :: string?,
	}, win32.pathmt)
end

function win32.resolve(...: pathlike): path
	local parts = { ... }
	if #parts == 0 then
		return win32.parse(process.cwd())
	end

	local path = win32.parse(parts[#parts])

	for i = #parts - 1, 1, -1 do
		if win32.isabsolute(path) then
			break
		end

		local segment = win32.parse(parts[i])

		if #segment.parts == 0 then
			continue
		end

		joinHelper(segment, path)
		path = segment
	end

	if not win32.isabsolute(path) then
		local cwd = win32.parse(process.cwd())
		joinHelper(cwd, path)
		path = cwd
	end

	return win32.normalize(path)
end

function win32.pathmt:__tostring(): string
	return win32.format(self :: path)
end

return table.freeze(win32)
