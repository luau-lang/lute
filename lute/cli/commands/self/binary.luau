local fs = require("@std/fs")
local process = require("@std/process")
local system = require("@std/system")

local function swapBinary(destination: string, new: string): ()
	local backup = `{destination}.old`
	pcall(fs.remove, backup)

	do
		local ok, err = pcall(fs.move, destination, backup)
		if not ok then
			pcall(fs.remove, backup)
			error(err)
		end
	end

	do
		local ok, err = pcall(fs.move, new, destination)
		if not ok then
			local restored, restoreErr = pcall(fs.move, backup, destination)
			if not restored then
				error(`Failed to install the new binary: {err}\nThe previous binary remains at {backup}: {restoreErr}`)
			end
			pcall(fs.remove, backup)
			error(err)
		end
	end

	pcall(fs.remove, backup)
end

local function installBinary(bytes: string, destination: string): ()
	local temporary = `{destination}.new`
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

return table.freeze({
	installBinary = installBinary,
})
