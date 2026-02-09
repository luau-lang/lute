local process = require("@lute/process")
local posixtypes = require("@self/types")
local pathinterface = require("./pathinterface")

export type path = posixtypes.path
export type pathlike = posixtypes.pathlike

local posix = {}
posix.pathmt = {} :: pathinterface.pathinterface

function posix.basename(path: pathlike): string?
	path = if typeof(path) == "string" then posix.parse(path) else path
	return if #path.parts > 0 then path.parts[#path.parts] else nil
end

function posix.dirname(path: pathlike): string
	path = if typeof(path) == "string" then posix.parse(path) else path

	if #path.parts == 0 then
		return posix.format(path)
	else
		return posix.format({
			parts = { table.unpack(path.parts, 1, #path.parts - 1) },
			absolute = path.absolute,
		})
	end
end

function posix.extname(path: pathlike): string
	path = if typeof(path) == "string" then posix.parse(path) else path

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

function posix.format(path: pathlike): string
	if typeof(path) == "string" then
		return path
	end

	if #path.parts == 0 then
		return if path.absolute then "/" else "."
	else
		return (if path.absolute then "/" else "") .. table.concat(path.parts, "/")
	end
end

function posix.isabsolute(path: pathlike): boolean
	path = if typeof(path) == "string" then posix.parse(path) else path
	return path.absolute
end

-- In place extends path with addend
local function joinHelper(path: path, addend: pathlike): ()
	addend = if typeof(addend) == "string" then posix.parse(addend) else addend

	if addend.absolute then
		local stringPath = posix.format(path)
		local stringAddend = posix.format(addend)
		error(
			`Could not join {if path.absolute then "absolute" else "relative"} path {stringPath} and absolute path {stringAddend}`
		)
	end

	table.move(addend.parts, 1, #addend.parts, #path.parts + 1, path.parts)
end

function posix.join(...: pathlike): path
	local parts: { pathlike } = { ... }
	if #parts == 0 then
		return setmetatable({
			parts = {},
			absolute = false,
		}, posix.pathmt)
	end

	local path: path = if typeof(parts[1]) == "string"
		then posix.parse(parts[1])
		else setmetatable({
			parts = table.clone((parts[1] :: path).parts), -- LUAUFIX: Shouldn't need cast
			absolute = (parts[1] :: path).absolute, -- LUAUFIX: Shouldn't need cast
		}, posix.pathmt)

	for i = 2, #parts do
		joinHelper(path, parts[i])
	end

	return path
end

function posix.normalize(path: pathlike): path
	path = if typeof(path) == "string" then posix.parse(path) else path

	local newParts = {}
	for _, part in path.parts do
		if part == "" or part == "." then
			continue
		elseif part == ".." then
			if path.absolute then
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
		absolute = path.absolute,
	}, posix.pathmt)
end

function posix.parse(path: pathlike): path
	if typeof(path) == "table" then
		return setmetatable(path, posix.pathmt)
	end
	if typeof(path) ~= "string" then
		error("Expected string or path")
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

	return setmetatable({
		parts = parts,
		absolute = isAbs,
	}, posix.pathmt)
end

function posix.resolve(...: pathlike): path
	local parts = { ... }
	if #parts == 0 then
		return posix.parse(process.cwd())
	end

	local path = posix.parse(parts[#parts])

	for i = #parts - 1, 1, -1 do
		if posix.isabsolute(path) then
			break
		end

		local segment = posix.parse(parts[i])

		if #segment.parts == 0 then
			continue
		end

		joinHelper(segment, path)
		path = segment
	end

	if not posix.isabsolute(path) then
		local cwd = posix.parse(process.cwd())
		joinHelper(cwd, path)
		path = cwd
	end

	return posix.normalize(path)
end

function posix.relative(from: pathlike, to: pathlike): path
	from = if typeof(from) == "string" then posix.parse(from) else from
	to = if typeof(to) == "string" then posix.parse(to) else to

	if from.absolute ~= to.absolute then
		error("Cannot compute relative path between absolute and relative paths")
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
		for i = commonPrefixLength + 1, #from.parts do
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
		absolute = false,
	}, posix.pathmt)
end

function posix.pathmt:__tostring(): string
	return posix.format(self :: path)
end

return table.freeze(posix)
