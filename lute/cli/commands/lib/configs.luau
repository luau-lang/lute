local fs = require("@std/fs")
local luau = require("@std/luau")
local path = require("@std/path")
local process = require("@std/process")

local function walkConfigPaths(startDir: string?): () -> (string, { [any]: any })
	local current = path.format(path.normalize(startDir or process.cwd()))

	return function(): (string, { [any]: any })
		while current do
			local candidate = path.format(path.join(current, ".config.luau"))

			local parent = path.format(path.dirname(current))
			if parent == current then
				current = nil
			else
				current = parent
			end

			if fs.exists(candidate) then
				local ok, root = pcall(luau.loadModule, candidate, nil)
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

return table.freeze({
	walkConfigPaths = walkConfigPaths,
})
