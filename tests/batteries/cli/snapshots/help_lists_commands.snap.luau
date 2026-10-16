local cli = require("@batteries/cli")

local p = cli.parser()
p:add("verbose", "flag", { aliases = { "v" }, help = "Enable verbose output" })
p:subcommand("plugin", { help = "Build the plugin" })
p:subcommand("package", { aliases = { "pkg" }, help = "Build a single package" })
p:subcommand("internal", { hidden = true, help = "Not shown in help" })
print(p:help())
