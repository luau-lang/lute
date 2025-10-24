-- Module B that requires A (circular dependency)
local a = require("./circular_a")

return {
	name = "B",
	a = a,
}
