-- Module A that requires B (circular dependency)
local b = require("./circular_b")

return {
	name = "A",
	b = b,
}
