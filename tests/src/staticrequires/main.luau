-- test that you can require in an alias aware fashion
local example = require("@example/option")
print(`Required {example.file} from alias @example`)

-- Entry point that requires other modules
local utils = require("./utils")
local lib = require("./lib/helper")
local otherModule = require("./other/module")
local process = require("@std/process")
local path = require("@std/path")

-- Use standard library to verify it works in compiled bundles
local cwd = path.format(process.cwd())
print("Main module running from: " .. cwd)

return {
	utils = utils,
	lib = lib,
	otherModule = otherModule,
	cwd = cwd,
}
