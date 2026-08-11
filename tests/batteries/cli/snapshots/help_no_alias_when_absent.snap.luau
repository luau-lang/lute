local cli = require("@batteries/cli")

local p = cli.parser()
p:add("verbose", "flag", { help = "Enable verbose output" })
print(p:help())
