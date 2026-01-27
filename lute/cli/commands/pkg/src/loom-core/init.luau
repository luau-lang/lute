local git = require("@self/packagesource/git")
local types = require("@self/loomtypes")
local install = require("@self/commands/install")

local loom = {} :: types.Loom

function loom:install()
	local packageSource = {} :: types.PackageSource
	packageSource.git = git

	install(packageSource)
end

return loom
