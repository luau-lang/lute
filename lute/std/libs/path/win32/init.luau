local process = require("@lute/process")
local win32types = require("@self/types")

export type pathkind = win32types.pathkind
export type path = win32types.path
export type pathlike = win32types.pathlike

local win32 = {}

function win32.basename(path: pathlike): string?
	if typeof(path) == "string" then
		path = win32.parse(path)
	end
	path = path :: path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function win32.dirname(path: pathlike): string
	if typeof(path) == "string" then
		path = win32.parse(path)
	end

	path = path :: path

	if #path.parts == 0 then
		return win32.format(path)
	else
		return win32.format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			kind = path.kind,
			driveLetter = path.driveLetter,
		})
	end
end

function win32.extname(path: pathlike): string
	if typeof(path) == "string" then
		path = win32.parse(path)
	end

	path = path :: path

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

function win32.format(path: pathlike): string
	if typeof(path) == "string" then
		return path
	end

	path = path :: path

	if #path.parts == 0 then
		if path.kind == "unc" then
			return "\\\\"
		elseif path.driveLetter ~= nil then
			return table.concat({ path.driveLetter, ":", (if path.kind == "absolute" then "\\" else "") })
		else
			return "."
		end
	else
		local parts = table.concat(path.parts, "\\")
		if path.kind == "unc" then
			return "\\\\" .. parts
		elseif path.driveLetter ~= nil then
			return table.concat({ path.driveLetter, ":", (if path.kind == "absolute" then "\\" else ""), parts })
		else
			return parts
		end
	end
end

function win32.isabsolute(path: pathlike): boolean
	if typeof(path) == "string" then
		path = win32.parse(path)
	end
	path = path :: path
	return path.kind == "absolute" or path.kind == "unc"
end

-- In place extends path with addend
local function joinHelper(path: path, addend: pathlike): ()
	if typeof(addend) == "string" then
		addend = win32.parse(addend)
	end
	addend = addend :: path

	if addend.kind == "absolute" or addend.kind == "unc" then
		local stringPath = win32.format(path)
		local stringAddend = win32.format(addend)
		error(table.concat({
			"Could not join ",
			path.kind,
			" path ",
			stringPath,
			" and ",
			addend.kind,
			" path ",
			stringAddend,
		}))
	end

	local driveLettersIncompatible = path.driveLetter ~= nil
		and addend.driveLetter ~= nil
		and addend.driveLetter:lower() ~= path.driveLetter:lower()

	if driveLettersIncompatible then
		local stringPath = win32.format(path)
		local stringAddend = win32.format(addend)
		error(
			table.concat({ "Could not join paths with incompatible drive letters: ", stringPath, " and ", stringAddend })
		)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)

	if path.driveLetter == nil and addend.driveLetter ~= nil then
		path.driveLetter = addend.driveLetter
	end
end

function win32.join(...: pathlike): path
	local parts = { ... }
	if #parts == 0 then
		return {
			parts = {},
			kind = "relative",
			driveLetter = nil,
		}
	end

	local path = win32.parse(parts[1])

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

function win32.normalize(path: pathlike): path
	if typeof(path) == "string" then
		path = win32.parse(path)
	end
	path = path :: path

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

	return {
		parts = newParts,
		kind = path.kind,
		driveLetter = path.driveLetter,
	}
end

function win32.parse(path: pathlike): path
	if typeof(path) == "table" then
		return path
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
		-- Windows: starts with drive letter + backslash (C:\)
		kind = if string.sub(path, 3, 3) == "\\" then "absolute" else "relative"
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

	return {
		parts = parts,
		kind = kind,
		driveLetter = driveLetter,
	}
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

return table.freeze(win32)
