local registry = require("@commands/pkg/loom-core/src/registry")

local registryUrl = select(2, ...)
assert(typeof(registryUrl) == "string", "Expected a registry URL argument")

registry.fetchUniverse(registryUrl, {
	{ name = "citrus", source = "citrus" },
})
