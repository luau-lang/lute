local fs = require("@std/fs")
local formatter = require("@std/syntax/format")
local printDiffHunks = require("../transform/printDiffHunks")

export type FormatResult = {
	ok: boolean,
	changed: boolean,
	output: string,
}

local function formatSource(source: string, label: string): (boolean, string)
	local ok, result = pcall(formatter.formatCode, source)
	if ok then
		return true, result
	end

	return false, `Error formatting {label}: {result}`
end

local function formatfile(args: { file: string, check: boolean }): FormatResult
	local pathStr = args.file
	local readOk, source = pcall(fs.readFileToString, pathStr)
	if not readOk then
		return {
			ok = false,
			changed = false,
			output = `Error reading {pathStr}: {source}\n`,
		}
	end

	local formatOk, result = formatSource(source, pathStr)
	if not formatOk then
		return {
			ok = false,
			changed = false,
			output = result .. "\n",
		}
	end

	if result == source then
		return {
			ok = true,
			changed = false,
			output = "",
		}
	end

	if args.check then
		local output = `Would reformat {pathStr}\n`
		local diff = printDiffHunks(source, result)
		if diff ~= "" then
			output ..= diff .. "\n"
		end

		return {
			ok = true,
			changed = true,
			output = output,
		}
	end

	local writeOk, err = pcall(fs.writeStringToFile, pathStr, result)
	if not writeOk then
		return {
			ok = false,
			changed = false,
			output = `Error writing {pathStr}: {err}\n`,
		}
	end

	return {
		ok = true,
		changed = true,
		output = `Formatted {pathStr}\n`,
	}
end

local function formatfiles(args: { files: { string }, check: boolean }): { FormatResult }
	local results = table.create(#args.files) :: { FormatResult }
	for index, file in args.files do
		results[index] = formatfile({
			file = file,
			check = args.check,
		})
	end
	return results
end

return table.freeze({
	formatfile = formatfile,
	formatfiles = formatfiles,
})
