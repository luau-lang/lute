local registry = require("@commands/pkg/loom-core/src/registry")

local registryUrl = select(2, ...)
assert(typeof(registryUrl) == "string", "Expected a registry URL argument")

registry.publishPackage(registryUrl, buffer.fromstring("package archive\0body"))
