local git = require("@self/src/packagesource/git")
local types = require("@self/src/loomtypes")
local install = require("@self/src/commands/install")

local loom = {} :: types.Loom

function loom:install()
	local packageSource = {} :: types.PackageSource
	packageSource.git = git

	install(packageSource)
end

return loom
