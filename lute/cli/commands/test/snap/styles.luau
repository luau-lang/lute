local rt = require("@batteries/richterm")

return table.freeze({
	bold = rt.bold,
	filepath = rt.cyan,
	dim = rt.dim,
	pass = rt.combine(rt.green, rt.bold),
	fail = rt.red,
	newstyle = rt.combine(rt.yellow, rt.bold),
})
