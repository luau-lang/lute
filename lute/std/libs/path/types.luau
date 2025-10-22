local posixtypes = require("@self/posix/types")
local win32types = require("@self/win32/types")

export type path = posixtypes.path | win32types.path
export type pathlike = string | path

return { "successfully exported path types" }
