const fs = require("@std/fs")
const luau = require("@std/luau")
const path = require("@std/path")
const process = require("@std/process")

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
				end
				if typeof(root) ~= "table" then
					error(`{candidate} must return a table`, 0)
				end
				return candidate, root
			end
		end

		return nil :: any, nil :: any
	end
end

return table.freeze(configLib)
