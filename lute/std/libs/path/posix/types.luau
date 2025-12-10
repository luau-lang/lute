local pathinterface = require("../pathinterface")

export type pathdata = {
	parts: { string },
	absolute: boolean,
}

export type path = setmetatable<pathdata, pathinterface.pathinterface>

export type pathlike = string | path | pathdata

return {}
