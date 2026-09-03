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

export type WorkspaceManifest = {
	read version: string?,
	read members: { string },
	read defaultMember: string?,
	read dependencies: { [string]: DependencySpec }?,
}

export type PackageManifest = {
	read name: string,
	read version: string,
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

local function resolveWorkspaceRefs(
	raw: any,
	workspaceDeps: { [string]: DependencySpec }?
): any
	if raw == nil then
		return nil
	end

	local hasWorkspaceRefs = false
	for _, spec in raw do
		if typeof(spec) == "table" and spec.workspace == true then
			hasWorkspaceRefs = true
			break
		end
	end

	if not hasWorkspaceRefs then
		return raw
	end

	local resolved: { [string]: any } = {}
	for name, spec in raw do
		if typeof(spec) == "table" and spec.workspace == true then
			assert(
				workspaceDeps ~= nil and (workspaceDeps :: { [string]: DependencySpec })[name] ~= nil,
				`Dependency '{name}' references workspace, but '{name}' is not defined in workspace.dependencies`
			)
			resolved[name] = (workspaceDeps :: { [string]: DependencySpec })[name]
		else
			resolved[name] = spec
		end
	end

	return resolved
end

local function parseWorkspace(raw: any): WorkspaceManifest
	assert(typeof(raw) == "table", "Expected 'workspace' field to be a table")

	assert(
		raw.version == nil or typeof(raw.version) == "string",
		"Expected 'version' in workspace to be a string"
	)

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
		dependencies = parseDependencyMap(raw.dependencies, "workspace.dependencies")
	end

	return table.freeze({
		version = raw.version,
		members = table.freeze(members),
		defaultMember = defaultMember,
		dependencies = dependencies,
	})
end

local function parsePackage(pkg: any): PackageManifest
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
		name = pkg.name,
		version = pkg.version,
		dependencies = dependencies,
		devDependencies = devDependencies,
	})
end

local function resolveWorkspaceField(raw: any, workspaceValue: string?, fieldName: string): string
	if raw == nil or (typeof(raw) == "table" and raw.workspace == true) then
		assert(
			workspaceValue ~= nil,
			`Member inherits '{fieldName}' from workspace, but workspace has no '{fieldName}'`
		)
		return workspaceValue :: string
	end
	assert(typeof(raw) == "string", `Expected '{fieldName}' to be a string or \{ workspace = true }`)
	return raw
end

local function parseMemberManifest(t: unknown, workspace: WorkspaceManifest?): PackageManifest
	assert(t ~= nil and typeof(t) == "table", "Expected a table")
	assert(t.package ~= nil and typeof(t.package) == "table", "Expected 'package' field in member manifest")

	local pkg = t.package

	assert(pkg.name ~= nil and typeof(pkg.name) == "string", "Expected 'name' field in member manifest")

	local version = resolveWorkspaceField((pkg :: any).version, if workspace then workspace.version else nil, "version")

	local workspaceDeps = if workspace then workspace.dependencies else nil
	local resolvedDeps = resolveWorkspaceRefs((pkg :: any).dependencies, workspaceDeps)
	local resolvedDevDeps = resolveWorkspaceRefs((pkg :: any).dev_dependencies, workspaceDeps)

	return parsePackage({
		name = pkg.name,
		version = version,
		dependencies = resolvedDeps,
		dev_dependencies = resolvedDevDeps,
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
		if workspace ~= nil then
			pkg = parseMemberManifest(raw, workspace)
			local members: { string } = table.clone((workspace :: WorkspaceManifest).members)
			table.insert(members, ".")
			workspace = table.freeze({
				version = (workspace :: WorkspaceManifest).version,
				members = table.freeze(members),
				defaultMember = (workspace :: WorkspaceManifest).defaultMember,
				dependencies = (workspace :: WorkspaceManifest).dependencies,
			})
		else
			pkg = parsePackage(raw.package)
		end
	end

	local overrides = parseDependencyMap(raw.overrides, "overrides")

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

local function parseMemberFile(manifestPath: string, workspace: WorkspaceManifest?): PackageManifest
	local manifestTable = luau.loadModule(manifestPath)
	return parseMemberManifest(manifestTable, workspace)
end

return {
	isSourceKind = isSourceKind,
	parseSourceKind = parseSourceKind,
	parseFile = parseFile,
	parseMemberFile = parseMemberFile,
}
