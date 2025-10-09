local strings = require("./strings")

local path = {}

function path.basename(filepath: string): string
	if filepath:sub(-1) == "/" then
		filepath = filepath:sub(1, #filepath - 1)
	end

	local reversed = string.reverse(filepath)
	local separator = reversed:find("/")

	if separator then
		return reversed:sub(1, separator - 1):reverse()
	else
		return filepath
	end
end

function path.dirname(filepath: string): string?
	if filepath:sub(-1) == "/" then
		filepath = filepath:sub(1, #filepath - 1)
	end

	local reversed = string.reverse(filepath)
	local separator = reversed:find("/")

	if separator then
		return reversed:sub(separator + 1):reverse()
	else
		return nil
	end
end

function path.isAbsolute(filepath: string): boolean
	return filepath:sub(1, 1) == "/"
end

function path.joinPath(basePath: string, file: string): string
	-- TODO: use a proper path library to join paths

	if file == "." then
		return basePath
	elseif strings.startsWith(file, "./") then
		file = strings.removePrefix(file, "./")
	end

	if basePath:sub(-1) == "/" then
		return basePath .. file
	else
		return `{basePath}/{file}`
	end
end

return path
