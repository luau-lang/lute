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

export type WorkspaceDependencySpec = {
	read sourceKind: "workspace",
	read name: string,
}

export type DependencySpec =
	PathDependencySpec
	| GitHubDependencySpec
	| RegistryDependencySpec
	| WorkspaceDependencySpec

export type WorkspaceInherit = {
	read workspace: true,
}

export type WorkspaceManifest = {
	read version: string?,
	read members: { string },
	read defaultMember: string?,
	read dependencies: { [string]: DependencySpec }?,
}

export type PackageManifest = {
	read name: string,
	read version: (string | WorkspaceInherit)?,
	read dependencies: { [string]: DependencySpec },
	read devDependencies: { [string]: DependencySpec },
}

export type ProjectManifest = {
	read package: PackageManifest?,
	read overrides: { [string]: DependencySpec },
	read workspace: WorkspaceManifest?,
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

local function parseDependencyMap(raw: any, sectionName: string, allowWorkspace: boolean): { [string]: DependencySpec }
	local result: { [string]: DependencySpec } = {}
	if raw == nil then
		return table.freeze(result)
	end

	for name, spec in raw do
		if typeof(spec) == "table" and spec.workspace == true then
			assert(allowWorkspace ~= false, `Workspace dependencies are not allowed in {sectionName}`)
			result[name] = table.freeze({
				name = name,
				sourceKind = "workspace" :: "workspace",
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

local function parseWorkspace(raw: any): WorkspaceManifest
	assert(typeof(raw) == "table", "Expected 'workspace' field to be a table")

	assert(raw.version == nil or typeof(raw.version) == "string", "Expected 'version' in workspace to be a string")

	assert(typeof(raw.members) == "table", "Expected 'members' field in workspace")
	local members: { string } = {}
	for i, member in raw.members do
		assert(typeof(member) == "string", `Expected workspace member at index {i} to be a string`)
		table.insert(members, member)
	end
	assert(#members > 0, "Workspace must have at least one member")

	local defaultMember: string? = nil
	if raw.default_member ~= nil then
		assert(typeof(raw.default_member) == "string", "Expected 'default_member' in workspace to be a string")
		local found = false
		for _, member in members do
			local basename = string.match(member, "[^/]+$") or member
			if basename == raw.default_member then
				found = true
				break
			end
		end
		assert(found, `default_member '{raw.default_member}' is not a basename of any workspace member`)
		defaultMember = raw.default_member
	end

	local dependencies: { [string]: DependencySpec }? = nil
	if raw.dependencies ~= nil then
		dependencies = parseDependencyMap(raw.dependencies, "workspace.dependencies", false)
	end

	return table.freeze({
		version = raw.version,
		members = table.freeze(members),
		defaultMember = defaultMember,
		dependencies = dependencies,
	})
end

-- TODO: We should do proper error handling because this is user input.
local function parseManifest(t: unknown): ProjectManifest
	assert(t ~= nil and typeof(t) == "table", "Expected a table")

	local raw = t :: any
	assert(
		raw.package ~= nil or raw.workspace ~= nil,
		"Expected at least one of 'package' or 'workspace' field in manifest"
	)

	local workspace: WorkspaceManifest? = nil
	if raw.workspace ~= nil then
		workspace = parseWorkspace(raw.workspace)
	end

	local pkg: PackageManifest? = nil
	if raw.package ~= nil then
		assert(typeof(raw.package) == "table", "Expected 'package' field to be a table")

		local rawPkg = raw.package
		assert(rawPkg.name ~= nil and typeof(rawPkg.name) == "string", "Expected 'name' field in package manifest")

		local rawVersion = (rawPkg :: any).version
		local version: (string | WorkspaceInherit)? = nil
		if typeof(rawVersion) == "string" then
			version = rawVersion
		elseif typeof(rawVersion) == "table" and rawVersion.workspace == true then
			version = table.freeze({ workspace = true :: true })
		else
			error("Expected 'version' field in package manifest to be a string or { workspace = true }")
		end

		local dependencies = parseDependencyMap((rawPkg :: any).dependencies, "dependencies", true)
		local devDependencies = parseDependencyMap((rawPkg :: any).dev_dependencies, "dev_dependencies", true)

		for alias in devDependencies do
			assert(dependencies[alias] == nil, `Alias '{alias}' appears in both dependencies and dev_dependencies`)
		end

		pkg = table.freeze({
			name = rawPkg.name,
			version = version,
			dependencies = dependencies,
			devDependencies = devDependencies,
		})
	end

	local overrides = parseDependencyMap(raw.overrides, "overrides", false)

	return table.freeze({
		package = pkg,
		overrides = overrides,
		workspace = workspace,
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
