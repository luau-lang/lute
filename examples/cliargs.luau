local cli = require("@batteries/cli")

local args = cli.parser()

args:add("input", "positional", { help = "Input file" })
args:add("verbose", "flag", { help = "Enable verbose mode", aliases = { "v" } })
args:add("output", "option", { help = "Output file", aliases = { "o" }, default = "default.txt" })

args:parse({ ... })

print("Input File:", args:get("input"))        -- "input.txt"
print("Verbose Mode:", args:has("verbose"))   -- true
print("Output File:", args:get("output"))     -- "result.txt"
