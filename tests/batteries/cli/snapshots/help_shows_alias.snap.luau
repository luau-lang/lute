local cli = require("@batteries/cli")

local p = cli.parser()
p:add("verbose", "flag", { aliases = { "v" }, help = "Enable verbose output" })
p:help()
