local process = require("@lute/process")
local win32types = require("@self/types")
local pathinterface = require("./pathinterface")

export type PathKind = win32types.PathKind
export type Path = win32types.Path
export type Pathlike = win32types.Pathlike

local win32 = {}
win32.pathmt = {} :: pathinterface.PathInterface

--- Returns the last component of `path`, or `nil` if the path has no components.
function win32.basename(path: Pathlike): string?
	path = if typeof(path) == "string" then win32.parse(path) else path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

--- Returns the directory portion of `path` as a string (everything except the last component).
function win32.dirname(path: Pathlike): string
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

--- Returns the file extension of `path` (including the leading dot), or `""` if there is none.
function win32.extname(path: Pathlike): string
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

--- Returns a `Path` representing just the drive root of `path` (e.g. `C:\`). Errors if `path` has no drive letter.
function win32.drive(path: Pathlike): Path
	path = if typeof(path) == "string" then win32.parse(path) else path

	if path.drive == nil then
		error("Path does not have a drive letter: " .. win32.format(path))
	end

	return setmetatable(
		{
			parts = {},
			kind = "absolute",
			drive = path.drive,
		} :: win32types.PathData,
		win32.pathmt
	)
end

--- Converts `path` to its Windows string representation using backslash separators.
function win32.format(path: Pathlike): string
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

--- Returns `true` if `path` is absolute (drive-rooted or UNC).
function win32.isAbsolute(path: Pathlike): boolean
	path = if typeof(path) == "string" then win32.parse(path) else path
	return path.kind ~= "relative"
end

-- In place extends path with addend
local function joinHelper(path: Path, addend: Pathlike): ()
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

--- Joins one or more path segments into a single `Path`. Each segment after the first must be relative.
function win32.join(...: Pathlike): Path
	local parts = { ... }
	if #parts == 0 then
		return setmetatable(
			{
				parts = {},
				kind = "relative",
				drive = nil,
			} :: win32types.PathData, -- Cast needed because of table invariance
			win32.pathmt
		)
	end

	local path: Path = if typeof(parts[1]) == "string"
		then win32.parse(parts[1])
		else setmetatable({
			parts = table.clone((parts[1] :: Path).parts), -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			kind = (parts[1] :: Path).kind, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
			drive = (parts[1] :: Path).drive, -- LUAUFIX: Shouldn't need cast, refinement should remove string from possible types of parts[1]
		}, win32.pathmt)

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

--- Returns a normalized form of `path`, resolving `.` and `..` components and removing redundant separators.
function win32.normalize(path: Pathlike): Path
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

--- Parses `path` into a structured `Path` value.
function win32.parse(path: Pathlike): Path
	if typeof(path) == "table" then
		return setmetatable(path, win32.pathmt)
	end
	if typeof(path) ~= "string" then
		error("Expected string or path")
	end

	local kind: PathKind = "relative"
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

--- Returns the relative path from `from` to `to`. Both paths must have the same kind and drive.
function win32.relative(from: Pathlike, to: Pathlike): Path
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

--- Resolves a sequence of paths into an absolute `Path`, processing right-to-left and falling back to the current working directory.
function win32.resolve(...: Pathlike): Path
	local parts = { ... }
	if #parts == 0 then
		return win32.parse(process.cwd())
	end

	local path = win32.parse(parts[#parts])

	for i = #parts - 1, 1, -1 do
		if win32.isAbsolute(path) then
			break
		end

		local segment = win32.parse(parts[i])

		if #segment.parts == 0 then
			continue
		end

		joinHelper(segment, path)
		path = segment
	end

	if not win32.isAbsolute(path) then
		local cwd = win32.parse(process.cwd())
		joinHelper(cwd, path)
		path = cwd
	end

	return win32.normalize(path)
end

function win32.pathmt:__tostring(): string
	return win32.format(self :: Path)
end

return table.freeze(win32)
