-- Entry point that requires other modules
local utils = require("./utils")
local lib = require("./lib/helper")

print("Main module")
return {
	utils = utils,
	lib = lib,
}
