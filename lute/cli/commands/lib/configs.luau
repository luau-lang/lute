const fs = require("@std/fs")
const luau = require("@std/luau")
const path = require("@std/path")
const process = require("@std/process")

const parseIgnores = require("./parseIgnores")

const configLib = {}

function configLib.walkConfigPaths(startDir: string?): () -> (string, { [any]: any })
	local current = path.format(path.normalize(startDir or process.cwd()))

	return function(): (string, { [any]: any })
		while current do
			const candidate = path.format(path.join(current, ".config.luau"))

			const parent = path.format(path.dirname(current))
			if parent == current then
				current = nil
			else
				current = parent
			end

			if fs.exists(candidate) then
				const ok, root = pcall(luau.loadModule, candidate, nil)
				if not ok then
					error(`Failed to load config {candidate}: {root}`, 0)
				elseif typeof(root) ~= "table" then
					error(`{candidate} must return a table`, 0)
				end
				return candidate, root
			end
		end

		return nil :: any, nil :: any
	end
end

-- Reads `lute.<command>.ignores` from the nearest config that sets it.
function configLib.findConfiguredIgnores(command: string, startDir: string?): parseIgnores.GitignoreData?
	for configPath, config in configLib.walkConfigPaths(startDir) do
		const luteConfig = config.lute
		if luteConfig == nil then
			continue
		elseif typeof(luteConfig) ~= "table" then
			error(`{configPath}: lute must be a table`, 0)
		end

		const commandConfig = luteConfig[command]
		if commandConfig == nil then
			continue
		elseif typeof(commandConfig) ~= "table" then
			error(`{configPath}: lute.{command} must be a table`, 0)
		end

		const ignores = commandConfig.ignores
		if ignores == nil then
			continue
		elseif typeof(ignores) ~= "table" then
			error(`{configPath}: lute.{command}.ignores must be an array of filepaths`, 0)
		end

		for index, ignore in ignores do
			if typeof(index) ~= "number" then
				error(`{configPath}: lute.{command}.ignores must be an array`, 0)
			elseif typeof(ignore) ~= "string" then
				error(`{configPath}: lute.{command}.ignores[{index}] must be a string`, 0)
			end
		end

		return parseIgnores.parseIgnoreContents(path.dirname(configPath), ignores)
	end

	return nil
end

return table.freeze(configLib)
