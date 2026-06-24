local fs = require("@std/fs")
local luau = require("@std/luau")

export type SourceKind = "path" | "github" | "registry"

export type PathDependencySpec = {
	read sourceKind: "path",
	read name: string,
	read source: string,
}

export type GitHubDependencySpec = {
	read sourceKind: "github",
	read name: string,
	read source: string,
	read rev: string,
}

export type RegistryDependencySpec = {
	read sourceKind: "registry",
	read name: string,
	read source: string,
	read version: string,
}

export type DependencySpec = PathDependencySpec | GitHubDependencySpec | RegistryDependencySpec

export type PackageManifest = {
	read name: string,
	read version: string,
	read dependencies: { [string]: DependencySpec },
	read devDependencies: { [string]: DependencySpec },
}

export type ProjectManifest = {
	read package: PackageManifest,
}

local function isSourceKind(s: unknown): boolean
	return s == "path" or s == "github" or s == "registry"
end

local function parseSourceKind(s: unknown): SourceKind?
	if not isSourceKind(s) then
		return nil
	end

	return s :: SourceKind
end

local function parseDependencyMap(raw: any, sectionName: string): { [string]: DependencySpec }
	local result: { [string]: DependencySpec } = {}
	if raw == nil then
		return table.freeze(result)
	end

	for name, spec in raw do
		assert(
			spec.name == nil or typeof(spec.name) == "string",
			`Optional 'name' field in dependency spec for '{name}' in {sectionName} expected to be a string`
		)
		assert(
			isSourceKind(spec.sourceKind),
			`Expected 'sourceKind' to be 'path', 'github', or 'registry' in dependency spec for '{name}' in {sectionName}, got '{spec.sourceKind}'`
		)
		assert(
			spec.source ~= nil and typeof(spec.source) == "string",
			`Expected 'source' field in dependency spec for '{name}' in {sectionName}`
		)

		if spec.sourceKind == "path" then
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "path" :: "path",
				source = spec.source,
			})
		elseif spec.sourceKind == "github" then
			assert(typeof(spec.rev) == "string", `Expected 'rev' field for github dependency '{name}' in {sectionName}`)
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "github" :: "github",
				source = spec.source,
				rev = spec.rev,
			})
		elseif spec.sourceKind == "registry" then
			assert(
				typeof(spec.version) == "string",
				`Expected 'version' field for registry dependency '{name}' in {sectionName}`
			)
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "registry" :: "registry",
				source = spec.source,
				version = spec.version,
			})
		end
	end

	return table.freeze(result)
end

-- TODO: We should do proper error handling because this is user input.
local function parseManifest(t: unknown): ProjectManifest
	assert(t ~= nil and typeof(t) == "table", "Expected a table")
	assert(t.package ~= nil and typeof(t.package) == "table", "Expected 'package' field in manifest")

	local pkg = t.package

	assert(pkg.name ~= nil and typeof(pkg.name) == "string", "Expected 'name' field in package manifest")
	-- FIXME(Luau): Luau currently refines `pkg` to have `version` based on this check, but
	-- also produces a type error for the access _in_ the condition without the cast here.
	assert(
		(pkg :: any).version ~= nil and typeof(pkg.version) == "string",
		"Expected 'version' field in package manifest"
	)

	local dependencies = parseDependencyMap((pkg :: any).dependencies, "dependencies")
	local devDependencies = parseDependencyMap((pkg :: any).dev_dependencies, "dev_dependencies")

	for alias in devDependencies do
		assert(dependencies[alias] == nil, `Alias '{alias}' appears in both dependencies and dev_dependencies`)
	end

	return table.freeze({
		package = table.freeze({
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
			devDependencies = devDependencies,
		}),
	})
end

local function resolvePath(directory: string): string
	return `{directory}/loom.config.luau`
end

local function parseFile(directory: string): ProjectManifest
	local manifestPath = resolvePath(directory)
	if not fs.exists(manifestPath) then
		error(`Manifest file not found: {manifestPath}`)
	end
	local manifestTable = luau.loadModule(manifestPath)
	return parseManifest(manifestTable)
end

return {
	isSourceKind = isSourceKind,
	parseSourceKind = parseSourceKind,
	parseFile = parseFile,
	resolvePath = resolvePath,
}
