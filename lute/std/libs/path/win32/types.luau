local pathinterface = require("../pathinterface")

export type Pathkind = "unc" | "absolute" | "relative"

export type PathData = {
	parts: { string },
	kind: Pathkind,
	drive: string?,
}

export type Path = setmetatable<PathData, pathinterface.PathInterface>

export type Pathlike = string | PathData | Path

return {}
