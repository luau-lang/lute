local pathinterface = require("../pathinterface")

export type PathKind = "unc" | "absolute" | "relative"

export type PathData = {
	parts: { string },
	kind: PathKind,
	drive: string?,
}

export type Path = setmetatable<PathData, pathinterface.PathInterface>

export type Pathlike = string | PathData | Path

return {}
