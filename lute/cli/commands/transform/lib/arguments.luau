local stringext = require("@std/stringext")

type Config = {
	--- Prevent making changes to files
	dryRun: boolean,
	--- Path to the migration module to execute
	migrationPath: string,
	--- Configuration flags to pass to the migration
	migrationOptions: { [string]: string },
	--- List of file paths to process
	--- Note: no directory traversal or filtering has been applied on this list
	filePaths: { string },
}

local function parse(arguments: { string }): Config
	-- TODO: replace with proper CLI system
	-- For now, first argument is the transformer script, whilst the rest are either flags or files to apply it on

	if #arguments < 2 then
		error("Usage: lute transform <transformer script> [options...] <files...>")
	end

	local config = {
		dryRun = false,
		migrationPath = nil :: string?,
		migrationOptions = {},
		filePaths = {},
	}

	local i = 1
	while i <= #arguments do
		local argument = arguments[i]

		if stringext.hasprefix(argument, "--") then
			local name = stringext.removeprefix(argument, "--")

			if config.migrationPath == nil then
				-- Options before the codemod file are parsed as options for the tool itself
				if name == "dry-run" then
					config.dryRun = true
				else
					error(`Unknown flag '--{name}'`)
				end
			else
				i += 1
				assert(i <= #arguments, `Missing value for '{name}'`)
				local value = arguments[i]

				config.migrationOptions[name] = value
			end
		else
			if config.migrationPath == nil then
				config.migrationPath = argument
			else
				table.insert(config.filePaths, argument)
			end
		end

		i += 1
	end

	assert(config.migrationPath, "ASSERTION FAILED: codemodPath ~= nil")

	return config
end

return {
	parse = parse,
}
