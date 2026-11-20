--!strict
local withinit = require("@withinit")
assert(withinit.util.name == "util")
assert(rawequal(require("@withinit/util"), withinit.util))
assert(require("@withinit/sub/inner") == "inner+sibling")

assert(require("@noinit/base64") == "base64")
assert(require("@noinit/nested/deep") == "deep")
assert(require("@noinit/dir") == "dir")
assert(not pcall(require, "@noinit"), "a root without an init file is not a module")

assert(not pcall(require, "@srconly"), "src/init.luau is not guessed as the entry")
assert(require("@srconly/src") == "srconly")

assert(not pcall(require, "@escapes"), "relative requires can't leave the install root")
