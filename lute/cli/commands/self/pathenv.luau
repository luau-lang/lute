local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local paths = require("./paths")

local BLOCK_BEGIN = "# >>> lute self install >>>"
local BLOCK_END = "# <<< lute self install <<<"
local PATH_EXPORT = 'export PATH="$HOME/.lute/bin:$PATH"'
local BLOCK = `\n\n{BLOCK_BEGIN}\n{PATH_EXPORT}\n{BLOCK_END}\n\n`

local function profilePath(name: string): string
	return path.format(path.join(process.homedir(), name))
end

local function profileCandidates(all: true?): { string }
	if all then
		return table.freeze({ ".bash_profile", ".bashrc", ".profile", ".zprofile", ".zshrc" })
	end

	local shell = path.basename(process.env.SHELL or "")
	if shell == "bash" then
		return table.freeze({ ".bash_profile", ".bashrc", ".profile" })
	elseif shell == "zsh" then
		return table.freeze({ ".zprofile", ".zshrc" })
	else
		return table.freeze({ ".profile" })
	end
end

local function preferredProfile(): string
	local names = profileCandidates()
	for _, name in names do
		local profile = profilePath(name)
		if fs.exists(profile) then
			return profile
		end
	end
	return profilePath(names[1])
end

local function readWindowsPath(): string
	local query = process.run({ "reg", "query", "HKCU\\Environment", "/v", "Path" })
	if not query.ok then
		return ""
	end
	return string.match(query.stdout, "REG_[A-Z_]+%s+(.-)\r?\n") or ""
end

local function writeWindowsPath(value: string): ()
	local result = process.run({
		"reg",
		"add",
		"HKCU\\Environment",
		"/v",
		"Path",
		"/t",
		"REG_EXPAND_SZ",
		"/d",
		value,
		"/f",
	})
	if not result.ok then
		error(`Failed to update the user PATH:\n{result.stderr}`)
	end
end

local function ensureOnPath(): ()
	local binDir = paths.binPath()

	if system.win32 then
		local current = readWindowsPath()

		for segment in string.gmatch(current, "[^;]+") do
			if string.lower(segment) == string.lower(binDir) then
				print(`{binDir} is already on PATH`)
				return
			end
		end

		local newValue = if current == "" then binDir else `{binDir};{current}`
		writeWindowsPath(newValue)
		print(`Added {binDir} to user PATH`)
		return
	end

	local profile = preferredProfile()
	local contents = if fs.exists(profile) then fs.readFileToString(profile) else ""
	if string.find(contents, BLOCK_BEGIN, 1, true) then
		print(`{binDir} is already configured in {profile}`)
		return
	end

	fs.writeStringToFile(profile, contents .. BLOCK)
	print(`Added {binDir} to PATH in {profile}`)
	print("Restart your shell or re-source the profile to pick up the change.")
end

local function removeFromPath(): { string }
	if system.win32 then
		local current = readWindowsPath()
		local binDir = paths.binPath()
		local kept = {}
		local removed = false
		for segment in string.gmatch(current, "[^;]+") do
			if string.lower(segment) == string.lower(binDir) then
				removed = true
			else
				table.insert(kept, segment)
			end
		end

		if not removed then
			return {}
		end

		writeWindowsPath(table.concat(kept, ";"))
		return { "HKCU\\Environment\\Path" }
	end

	local touched = {}
	for _, name in profileCandidates(true) do
		local profile = profilePath(name)
		if not fs.exists(profile) then
			continue
		end

		local contents = fs.readFileToString(profile)
		local startPos = string.find(contents, BLOCK_BEGIN, 1, true)
		if startPos == nil then
			continue
		end

		local endPos = string.find(contents, BLOCK_END, startPos, true)
		if endPos == nil then
			continue
		end

		local before = string.sub(contents, 1, startPos - 1)
		local after = string.sub(contents, endPos + #BLOCK_END)
		before = string.gsub(before, "\n$", "")
		after = string.gsub(after, "^\n", "")

		local result = if #before > 0 and #after > 0 then `{before}\n{after}` elseif #before > 0 then before else after

		fs.writeStringToFile(profile, result)
		table.insert(touched, profile)
	end
	return touched
end

return table.freeze({
	ensureOnPath = ensureOnPath,
	removeFromPath = removeFromPath,
})
