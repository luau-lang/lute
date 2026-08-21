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
	read registry: string?,
}

export type RegistryConfig = {
	read url: string,
	read default: boolean?,
}

export type RegistryMap = { [string]: RegistryConfig }

export type DependencySpec = PathDependencySpec | GitHubDependencySpec | RegistryDependencySpec

export type PackageManifest = {
	read name: string,
	read version: string,
	read dependencies: { [string]: DependencySpec },
	read devDependencies: { [string]: DependencySpec },
}

export type ProjectManifest = {
	read package: PackageManifest,
	read overrides: { [string]: DependencySpec },
	read registry: RegistryMap,
	read defaultRegistry: string?,
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
			assert(
				spec.registry == nil or typeof(spec.registry) == "string",
				`Optional 'registry' field for dependency '{name}' in {sectionName} must be a string`
			)
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "registry" :: "registry",
				source = spec.source,
				version = spec.version,
				registry = spec.registry,
			})
		end
	end

	return table.freeze(result)
end

local function parseRegistryMap(raw: any): (RegistryMap, string?)
	local result: RegistryMap = {}
	if raw == nil then
		return table.freeze(result), nil
	end

	assert(typeof(raw) == "table", "Expected 'registry' to be a table")

	local defaultCount = 0
	local defaultName: string? = nil
	local hasExplicitFalse = false
	local firstName: string? = nil
	local count = 0

	for name, entry in raw do
		assert(typeof(name) == "string", "Expected registry key to be a string")
		assert(typeof(entry) == "table", `Expected registry entry '{name}' to be a table`)
		assert(typeof(entry.url) == "string", `Expected 'url' field in registry '{name}'`)

		local isDefault: boolean? = nil
		if entry.default ~= nil then
			assert(typeof(entry.default) == "boolean", `Expected 'default' to be a boolean in registry '{name}'`)
			isDefault = entry.default
			if isDefault then
				defaultCount += 1
				defaultName = name
			else
				hasExplicitFalse = true
			end
		end

		if count == 0 then
			firstName = name
		end

		result[name] = table.freeze({
			url = entry.url,
			default = if isDefault == true then true else nil,
		})
		count += 1
	end

	if count > 0 and defaultCount == 0 then
		if count > 1 or hasExplicitFalse then
			assert(false, "Registry configuration must have exactly one registry with 'default = true'")
		end
	elseif count > 1 and defaultCount > 1 then
		assert(false, `Multiple registries have 'default = true' (found {defaultCount})`)
	end

	local resolvedDefault: string? = nil
	if defaultCount == 1 then
		resolvedDefault = defaultName
	elseif count == 1 and defaultCount == 0 then
		resolvedDefault = firstName
	end

	return table.freeze(result), resolvedDefault
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

	local overrides = parseDependencyMap((t :: any).overrides, "overrides")
	local registryMap, defaultRegistry = parseRegistryMap((t :: any).registry)

	return table.freeze({
		package = table.freeze({
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
			devDependencies = devDependencies,
		}),
		overrides = overrides,
		registry = registryMap,
		defaultRegistry = defaultRegistry,
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
