local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local paths = require("./paths")

local function swapBinary(destination: string, temporary: string): ()
	local directory = path.dirname(destination)
	local backup = path.format(path.join(directory, `{paths.exeName()}.old`))
	pcall(fs.remove, backup)

	do
		local ok, err = pcall(fs.move, destination, backup)
		if not ok then
			pcall(fs.remove, temporary)
			error(err)
		end
	end

	do
		local ok, err = pcall(fs.move, temporary, destination)
		if not ok then
			pcall(fs.move, backup, destination)
			pcall(fs.remove, temporary)
			error(err)
		end
	end

	pcall(fs.remove, backup)
end

local function installBinary(bytes: string, destination: string): ()
	local directory = path.dirname(destination)
	local temporary = path.format(path.join(directory, `{paths.exeName()}.new`))
	pcall(fs.remove, temporary)
	fs.writeStringToFile(temporary, bytes)

	if not system.win32 then
		local result = process.run({ "chmod", "+x", temporary })
		if not result.ok then
			pcall(fs.remove, temporary)
			error(`Failed to mark {temporary} executable:\n{result.stderr}`)
		end
	end

	if not system.win32 or not fs.exists(destination) then
		local ok, err = pcall(fs.move, temporary, destination)
		if not ok then
			pcall(fs.remove, temporary)
			error(err)
		end
	else
		local ok, err = pcall(swapBinary, destination, temporary)
		if not ok then
			pcall(fs.remove, temporary)
			error(err)
		end
	end

	pcall(fs.remove, temporary)
end

return {
	installBinary = installBinary,
}
