local args = { ... }

local install = require("@self/loom-core/src/commands/install")

if args[1] == "install" then
	install()
else
	error("Usage: `lute pkg install`")
end
