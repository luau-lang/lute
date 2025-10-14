export type WindowsPath = {
	parts: { string },
	isAbsolute: boolean,
	isUNCPath: boolean,
	driveLetter: string?,
}

export type WindowsPathLike = string | WindowsPath

function basename(path: WindowsPathLike): string?
	if typeof(path) == "string" then
		path = parse(path)
	end
	path = path :: WindowsPath
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function dirname(path: WindowsPathLike): string
	if typeof(path) == "string" then
		path = parse(path)
	end

	path = path :: WindowsPath

	if #path.parts == 0 then
		return format(path)
	else
		return format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			isAbsolute = path.isAbsolute,
			isUNCPath = path.isUNCPath,
			driveLetter = path.driveLetter,
		})
	end
end

function extname(path: WindowsPathLike): string
	if typeof(path) == "string" then
		path = parse(path)
	end

	path = path :: WindowsPath

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

function format(path: WindowsPathLike): string
	if typeof(path) == "string" then
		return path
	end

	path = path :: WindowsPath

	if #path.parts == 0 then
		if path.isUNCPath then
			return "\\\\"
		elseif path.driveLetter ~= nil then
			return path.driveLetter .. ":" .. (if path.isAbsolute then "\\" else "")
		else
			return "."
		end
	else
		if path.isUNCPath then
			return "\\\\" .. table.concat(path.parts, "\\")
		elseif path.driveLetter ~= nil then
			return path.driveLetter .. ":" .. (if path.isAbsolute then "\\" else "") .. table.concat(path.parts, "\\")
		else
			return table.concat(path.parts, "\\")
		end
	end
end

function isabsolute(path: WindowsPathLike): boolean
	if typeof(path) == "string" then
		path = parse(path)
	end
	path = path :: WindowsPath
	return path.isAbsolute
end

-- In place extends path with addend
function _joinHelper(path: WindowsPath, addend: WindowsPathLike): ()
	if typeof(addend) == "string" then
		addend = parse(addend)
	end
	addend = addend :: WindowsPath

	if addend.isAbsolute then
		local stringPath = format(path)
		local stringAddend = format(addend)
		error(
			"Could not join "
				.. (if path.isAbsolute then "absolute" else "relative")
				.. " path "
				.. stringPath
				.. " and absolute path "
				.. stringAddend
		)
	end

	if addend.isUNCPath then
		local stringPath = format(path)
		local stringAddend = format(addend)
		error(
			"Could not join "
				.. (if path.isUNCPath then "UNC" else "non-UNC")
				.. " path "
				.. stringPath
				.. " and UNC path "
				.. stringAddend
		)
	end

	local driveLettersIncompatible = if path.driveLetter ~= nil
		then addend.driveLetter ~= nil and addend.driveLetter:lower() ~= path.driveLetter:lower()
		else addend.driveLetter ~= nil

	if driveLettersIncompatible then
		local stringPath = format(path)
		local stringAddend = format(addend)
		error("Could not join paths with incompatible drive letters: " .. stringPath .. " and " .. stringAddend)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)
end

function join(parts: { WindowsPathLike }): WindowsPath
	if #parts == 0 then
		return {
			parts = {},
			isAbsolute = false,
			isUNCPath = false,
			driveLetter = nil,
		}
	end

	local path = parse(parts[1])

	for i = 2, #parts do
		_joinHelper(path, parts[i])
	end

	return path
end

function normalize(path: WindowsPathLike): string
	error("TODO")
end

function parse(path: WindowsPathLike): WindowsPath
	if typeof(path) == "table" then
		return path
	end
	if typeof(path) ~= "string" then
		error("Expected string or PathObj")
	end

	local isAbs = false
	local isUNC = false
	local driveLetter = nil

	-- Check if path is absolute and if it's a UNC path on Windows
	if string.sub(path, 1, 2) == "\\\\" then
		-- UNC path
		isAbs = true
		isUNC = true
	elseif string.match(path, "^%a:") ~= nil then
		driveLetter = string.sub(path, 1, 1)
		-- Windows: starts with drive letter + backslash (C:\)
		isAbs = string.sub(path, 3, 3) == "\\"
	end

	local parts = {}
	-- Windows supports mixed separators, so sub forward slashes for backslashes first
	path = path:gsub("/", "\\")

	if isUNC then
		-- Strip out the leading \\ for UNC paths
		parts = path:sub(3):split("\\")
	elseif isAbs then
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
		isAbsolute = isAbs,
		isUNCPath = isUNC,
		driveLetter = driveLetter,
	}
end

function resolve(parts: { WindowsPathLike }): string
	error("TODO")
end

return table.freeze({
	basename = basename,
	dirname = dirname,
	extname = extname,
	format = format,
	isabsolute = isabsolute,
	join = join,
	normalize = normalize,
	parse = parse,
	resolve = resolve,
})
