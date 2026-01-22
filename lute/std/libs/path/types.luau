local posixtypes = require("@std/path/posix/types")
local win32types = require("@std/path/win32/types")

export type path = posixtypes.path | win32types.path
export type pathlike = posixtypes.pathlike | win32types.pathlike

return {}
