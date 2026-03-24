local posixtypes = require("@std/path/posix/types")
local win32types = require("@std/path/win32/types")

export type Path = posixtypes.Path | win32types.Path
export type Pathlike = posixtypes.Pathlike | win32types.Pathlike

return {}
