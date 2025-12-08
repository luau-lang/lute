local posixtypes = require("@std/path/posix/types")
local win32types = require("@std/path/win32/types")

export type path = posixtypes.pathdata | win32types.pathdata
export type pathlike = string | path

return {}
