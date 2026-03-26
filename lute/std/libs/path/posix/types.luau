local pathinterface = require("../pathinterface")

export type PathData = {
	parts: { string },
	absolute: boolean,
}

export type Path = setmetatable<PathData, pathinterface.PathInterface>

export type Pathlike = string | Path | PathData

return {}
