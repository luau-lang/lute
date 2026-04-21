local env = require("@batteries/env")
local path = require("@std/path")
local process = require("@std/process")

local source = debug.info(1, "s")
assert(source, "unable to determine the example source path")

local exampleDir = path.dirname(source)
local envFile = path.join(exampleDir, ".env")

local values = env.config({
	path = envFile,
	expand = true,
	override = true,
})

local keys = {}
for key in values do
	table.insert(keys, key)
end
table.sort(keys)

print("Loaded values:")
for _, key in keys do
	print(`{key}={values[key]}`)
end

print("")
print("From process.env:")
print("WELCOME_MESSAGE=", process.env.WELCOME_MESSAGE)
