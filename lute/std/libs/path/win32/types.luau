local pathinterface = require("../pathinterface")

--- Describes how a Windows path is rooted:
--- - `"absolute"`: Drive-rooted path, e.g. `C:\foo`.
--- - `"unc"`: UNC path, e.g. `\\server\share`.
--- - `"relative"`: A path with no drive or UNC root.
export type PathKind = "unc" | "absolute" | "relative"

--- The raw data of a Windows path: an array of components, the path kind, and an optional drive letter.
export type PathData = {
	parts: { string },
	kind: PathKind,
	drive: string?,
}

--- A structured Windows path.
export type Path = setmetatable<PathData, pathinterface.PathInterface>

--- Anything that can be used as a Windows path: a string, a `Path`, or raw `PathData`.
export type Pathlike = string | PathData | Path

return {}
