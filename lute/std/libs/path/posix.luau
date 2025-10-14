export type PosixPath = {
	parts: { string },
	isAbsolute: boolean,
}

export type PosixPathLike = string | PosixPath

function basename(path: PosixPathLike): string?
	if typeof(path) == "string" then
		path = parse(path)
	end
	path = path :: PosixPath
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function dirname(path: PosixPathLike): string
	if typeof(path) == "string" then
		path = parse(path)
	end

	path = path :: PosixPath

	if #path.parts == 0 then
		return format(path)
	else
		return format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			isAbsolute = path.isAbsolute,
		})
	end
end

function extname(path: PosixPathLike): string
	if typeof(path) == "string" then
		path = parse(path)
	end

	path = path :: PosixPath

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

function format(path: PosixPathLike): string
	if typeof(path) == "string" then
		return path
	end

	path = path :: PosixPath

	if #path.parts == 0 then
		return if path.isAbsolute then "/" else "."
	else
		return (if path.isAbsolute then "/" else "") .. table.concat(path.parts, "/")
	end
end

function isabsolute(path: PosixPathLike): boolean
	if typeof(path) == "string" then
		path = parse(path)
	end
	path = path :: PosixPath
	return path.isAbsolute
end

-- In place extends path with addend
function _joinHelper(path: PosixPath, addend: PosixPathLike): ()
	if typeof(addend) == "string" then
		addend = parse(addend)
	end
	addend = addend :: PosixPath

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

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)
end

function join(parts: { PosixPathLike }): PosixPath
	if #parts == 0 then
		return {
			parts = {},
			isAbsolute = false,
		}
	end

	local path = parse(parts[1])

	for i = 2, #parts do
		_joinHelper(path, parts[i])
	end

	return path
end

function normalize(path: PosixPathLike): string
	error("TODO")
end

function parse(path: PosixPathLike): PosixPath
	if typeof(path) == "table" then
		return path
	end
	if typeof(path) ~= "string" then
		error("Expected string or PosixPath")
	end

	local isAbs = false

	-- Check if path is absolute
	isAbs = string.sub(path, 1, 1) == "/"

	local parts = {}
	if isAbs then
		-- Strip out the leading / for absolute paths
		parts = path:sub(2):split("/")
	else
		parts = path:split("/")
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
	}
end

function resolve(parts: { PosixPathLike }): string
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
