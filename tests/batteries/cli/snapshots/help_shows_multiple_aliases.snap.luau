local cli = require("@batteries/cli")

local p = cli.parser()
p:add("verbose", "flag", { aliases = { "v", "V" }, help = "Enable verbose output" })
p:help()
