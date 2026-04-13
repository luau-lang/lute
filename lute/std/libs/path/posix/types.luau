local pathinterface = require("../pathinterface")

--- The raw data of a POSIX path: an array of components and a flag indicating whether the path is absolute.
export type PathData = {
	parts: { string },
	absolute: boolean,
}

--- A structured POSIX path.
export type Path = setmetatable<PathData, pathinterface.PathInterface>

--- Anything that can be used as a POSIX path: a string, a `Path`, or raw `PathData`.
export type Pathlike = string | Path | PathData

return {}
