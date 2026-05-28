local luau = require("@std/luau")

export type SourceKind = "path" | "github"

export type DependencySpec = {
	read name: string,
	read rev: string?,
	read source: string,
	read sourceKind: SourceKind,
}

export type PackageManifest = {
	read name: string,
	read version: string,
	read dependencies: { [string]: DependencySpec }, -- maps alias to dependency spec
}

export type ProjectManifest = {
	read package: PackageManifest,
}

local function isSourceKind(s: unknown): boolean
	return s == "path" or s == "github"
end

local function parseSourceKind(s: unknown): SourceKind?
	if not isSourceKind(s) then
		return nil
	end

	return s :: SourceKind
end

-- FIXME(Luau): running into issues with getting this to type check properly.
-- We also should also do proper error handling because this is user input.
local function parseManifest(t: any): ProjectManifest
	assert(t ~= nil and type<<unknown>>(t) == "table", "Expected a table")
	assert(t.package ~= nil and type(t.package) == "table", "Expected 'package' field in manifest")

	local pkg = t.package

	assert(pkg.name ~= nil and type(pkg.name) == "string", "Expected 'name' field in package manifest")
	assert(pkg.version ~= nil and type(pkg.version) == "string", "Expected 'version' field in package manifest")

	local dependencies: { [string]: DependencySpec } = {}
	if pkg.dependencies ~= nil then
		for name, spec in pkg.dependencies do
			assert(
				spec.name == nil or type(spec.name) == "string",
				`Optional 'name' field in dependency spec for '{name}' expected to be a string`
			)
			assert(
				spec.rev == nil or type(spec.rev) == "string",
				`Expected 'rev' field to be a string or nil in dependency spec for '{name}'`
			)
			assert(
				isSourceKind(spec.sourceKind),
				`Expected 'sourceKind' to be 'path' or 'github' in dependency spec for '{name}', got '{spec.sourceKind}'`
			)
			assert(
				spec.source ~= nil and type(spec.source) == "string",
				`Expected 'source' field in dependency spec for '{name}'`
			)
			dependencies[name] = table.freeze({
				name = spec.name or name, -- use the optional name if provided, otherwise use the alias
				rev = spec.rev,
				sourceKind = spec.sourceKind,
				source = spec.source,
			})
		end
		table.freeze(dependencies)
	end

	return table.freeze({
		package = table.freeze({
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
		}),
	})
end

local function parseFile(manifestPath: string): ProjectManifest
	local manifestTable = luau.loadModule(manifestPath)
	return parseManifest(manifestTable)
end

return {
	isSourceKind = isSourceKind,
	parseSourceKind = parseSourceKind,
	parseFile = parseFile,
}
