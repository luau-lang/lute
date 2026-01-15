local git = require("./package_source/git")
local types = require("./loom_types")
local install = require("./commands/install")

local loom = {} :: types.Loom

function loom:install()
	local package_source = {} :: types.PackageSource
	package_source.git = git

	install(package_source)
end

return loom
