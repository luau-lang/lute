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
	-- Unlike path/GitHub dependencies, the registry package name is always
	-- derived from source. Registry entries use the map key as their alias.
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

export type WorkspaceManifest = {
	read version: string?,
	read members: { string },
	read defaultMember: string?,
}

export type ProjectManifest = {
	read package: PackageManifest?,
	read workspace: WorkspaceManifest?,
	read overrides: { [string]: DependencySpec },
	read registry: string?,
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
		if typeof(spec) == "string" then
			result[name] = table.freeze({
				name = name,
				sourceKind = "registry" :: "registry",
				source = name,
				version = spec,
			})
			continue
		end

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
				spec.name == nil,
				`Registry dependency '{name}' in {sectionName} does not support a 'name' field; use 'source' for the registry package name`
			)
			result[name] = table.freeze({
				name = spec.source,
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
	local raw = t :: any
	assert(raw.package ~= nil or raw.workspace ~= nil, "Expected 'package' or 'workspace' field in manifest")

	local parsedPackage: PackageManifest? = nil
	if raw.package ~= nil then
		assert(typeof(raw.package) == "table", "Expected 'package' field in manifest to be a table")
		local pkg = raw.package
		assert(pkg.name ~= nil and typeof(pkg.name) == "string", "Expected 'name' field in package manifest")
		-- FIXME(Luau): Luau currently refines `pkg` to have `version` based on this check, but
		-- also produces a type error for the access _in_ the condition without the cast here.
		assert(pkg.version ~= nil and typeof(pkg.version) == "string", "Expected 'version' field in package manifest")

		local dependencies = parseDependencyMap(pkg.dependencies, "dependencies")
		local devDependencies = parseDependencyMap(pkg.dev_dependencies, "dev_dependencies")
		for alias in devDependencies do
			assert(dependencies[alias] == nil, `Alias '{alias}' appears in both dependencies and dev_dependencies`)
		end

		parsedPackage = table.freeze({
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
			devDependencies = devDependencies,
		})
	end

	local parsedWorkspace: WorkspaceManifest? = nil
	if raw.workspace ~= nil then
		assert(typeof(raw.workspace) == "table", "Expected 'workspace' field in manifest to be a table")
		local workspace = raw.workspace
		assert(
			workspace.members ~= nil and typeof(workspace.members) == "table",
			"Expected 'members' field in workspace manifest"
		)
		local members: { string } = {}
		for index, member in workspace.members do
			assert(typeof(member) == "string", `Expected workspace member at index '{index}' to be a string`)
			table.insert(members, member)
		end
		assert(
			workspace.version == nil or typeof(workspace.version) == "string",
			"Expected workspace version to be a string"
		)
		assert(
			workspace.default_member == nil or typeof(workspace.default_member) == "string",
			"Expected workspace default_member to be a string"
		)
		parsedWorkspace = table.freeze({
			version = workspace.version,
			members = table.freeze(members),
			defaultMember = workspace.default_member,
		})
	end

	local overrides = parseDependencyMap(raw.overrides, "overrides")

	local registry: string? = nil
	if raw.registry ~= nil then
		assert(typeof(raw.registry) == "string", "Expected 'registry' field to be a string URL")
		registry = raw.registry
	end

	return table.freeze({
		package = parsedPackage,
		workspace = parsedWorkspace,
		overrides = overrides,
		registry = registry,
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
