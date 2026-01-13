local args = {...}

local loom = require("@self/src/loom/loom")

if args[1] == "install" then
	loom:install()
else
	error("Usage: `lute pkg install`")
end
