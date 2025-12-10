local pathinterface = require("../pathinterface")

export type pathkind = "unc" | "absolute" | "relative"

export type pathdata = {
	parts: { string },
	kind: pathkind,
	drive: string?,
}

export type path = setmetatable<pathdata, pathinterface.pathinterface>

export type pathlike = string | pathdata | path

return {}
