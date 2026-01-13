local git = require("./package_source/git")
local types = require("./loom_types")
local install = require("./commands/install")

local loom = {} :: types.loom

function loom:install()
	local package_source = {} :: types.package_source
	package_source.git = git

	install(package_source)
end

return loom
