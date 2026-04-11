local luau = require("@std/luau")

-- TODO: Support path/registry dependencies
export type DependencySpec = {
	name: string,
	rev: string,
	source: string,
	sourceKind: string,
}

export type PackageManifest = {
	name: string,
	version: string,
	dependencies: { [string]: DependencySpec },
}

export type ProjectManifest = {
	package: PackageManifest,
}

-- FIXME(Luau): running into issues with getting this to type check properly.
-- We also should also do proper error handling because this is user input.
local function parseTable(t: any): ProjectManifest
	assert(t ~= nil and type<<unknown>>(t) == "table", "Expected a table")
	assert(t.package ~= nil and type(t.package) == "table", "Expected 'package' field in manifest")

	local pkg = t.package

	assert(pkg.name ~= nil and type(pkg.name) == "string", "Expected 'name' field in package manifest")
	assert(pkg.version ~= nil and type(pkg.version) == "string", "Expected 'version' field in package manifest")

	local dependencies: { [string]: DependencySpec } = {}
	if pkg.dependencies ~= nil then
		for name, spec in pkg.dependencies do
			assert(spec.rev ~= nil and type(spec.rev) == "string", `Expected 'rev' field in dependency spec for '{name}'`)
			assert(
				spec.sourceKind ~= nil and type(spec.sourceKind) == "string",
				`Expected 'sourceKind' field in dependency spec for '{name}'`
			)
			assert(
				spec.source ~= nil and type(spec.source) == "string",
				`Expected 'source' field in dependency spec for '{name}'`
			)
			dependencies[name] = {
				name = name,
				rev = spec.rev,
				sourceKind = spec.sourceKind,
				source = spec.source,
			}
		end
	end

	return {
		package = {
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
		},
	}
end

local function parseFile(manifestPath: string): ProjectManifest
	local manifestTable = luau.loadModule(manifestPath)
	return parseTable(manifestTable)
end

return {
	parseFile = parseFile,
}
