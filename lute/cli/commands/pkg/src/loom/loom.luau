local git = require("./packagesource/git")
local types = require("./loomtypes")
local install = require("./commands/install")

local loom = {} :: types.Loom

function loom:install()
	local packageSource = {} :: types.PackageSource
	packageSource.git = git

	install(packageSource)
end

return loom
