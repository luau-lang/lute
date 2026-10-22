local luau = require("@std/luau")
local path = require("@std/path")

export type SourceKind = "path" | "github" | "registry"

export type PathDependencySpec = {
	read sourceKind: "path",
	read name: string,
	read source: string,
	-- normalized absolute path resolved from the declaring manifest, everything
	-- after parsing uses this
	read directory: string,
	-- A publish-only registry requirement
	read version: string?,
}

export type GitHubDependencySpec = {
	read sourceKind: "github",
	read name: string,
	read source: string,
	read rev: string,
	read target: string?,
	-- A publish-only registry requirement
	read version: string?,
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
	-- A root manifest may omit both fields to act as a virtual package. Source
	-- dependencies must always include both. If one field is included the other
	-- must be included
	read name: string?,
	read version: string?,
	read contentRoot: string?,
	-- Publish filters relative to contentRoot. Positive patterns include files;
	-- patterns prefixed with ! exclude them.
	read files: { string }?,
	read dependencies: { [string]: DependencySpec },
	read devDependencies: { [string]: DependencySpec },
}

export type ProjectManifest = {
	read package: PackageManifest,
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

-- A GitHub target is always relative to the fetched repository root. Keep its
-- lockfile/source identity canonical before resolution uses it.
local function parseTarget(target: unknown, name: string, sectionName: string): string?
	if target == nil then
		return nil
	end
	assert(
		typeof(target) == "string",
		`Optional 'target' field for github dependency '{name}' in {sectionName} expected to be a string`
	)
	assert(
		not path.posix.isAbsolute(target),
		`'target' for github dependency '{name}' in {sectionName} must be relative to the repository root`
	)

	local normalized = path.posix.normalize(target)
	assert(
		normalized.parts[1] ~= "..",
		`'target' for github dependency '{name}' in {sectionName} must stay inside the repository`
	)
	if #normalized.parts == 0 then
		return nil
	end
	return path.posix.format({
		parts = normalized.parts,
		absolute = false,
	})
end

local function parseContentRoot(contentRoot: unknown): string?
	if contentRoot == nil then
		return nil
	end

	assert(typeof(contentRoot) == "string" and #contentRoot > 0, "Expected 'content_root' to be a non-empty string")
	assert(not path.posix.isAbsolute(contentRoot), "'content_root' must be relative to the package directory")

	local normalized = path.posix.normalize(contentRoot)
	assert(normalized.parts[1] ~= "..", "'content_root' must stay inside the package directory")
	if #normalized.parts == 0 then
		return nil
	end
	return path.posix.format({
		parts = normalized.parts,
		absolute = false,
	})
end

local function parseFiles(files: unknown): { string }?
	if files == nil then
		return nil
	end

	assert(typeof(files) == "table", "Expected 'files' field in package manifest to be an array of strings")
	local patterns = files :: { [number]: unknown }
	local length = 0
	for index, pattern in patterns do
		assert(
			typeof(index) == "number" and index >= 1 and index % 1 == 0 and typeof(pattern) == "string",
			"Expected 'files' field in package manifest to be an array of strings"
		)
		length += 1
	end
	for index = 1, length do
		assert(patterns[index] ~= nil, "Expected 'files' field in package manifest to be an array of strings")
	end
	return table.freeze(table.clone(patterns :: { string }))
end

local function parseDependencyMap(
	raw: any,
	sectionName: string,
	manifestDirectory: string
): { [string]: DependencySpec }
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
		assert(
			spec.version == nil or typeof(spec.version) == "string",
			`Optional 'version' field in dependency spec for '{name}' in {sectionName} expected to be a string`
		)
		if spec.sourceKind == "path" then
			assert(
				spec.target == nil,
				`Path dependency '{name}' in {sectionName} does not support a 'target' field; point 'source' directly at the package`
			)
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "path" :: "path",
				source = spec.source,
				directory = path.format(path.resolve(manifestDirectory, spec.source)),
				version = spec.version,
			})
		elseif spec.sourceKind == "github" then
			assert(typeof(spec.rev) == "string", `Expected 'rev' field for github dependency '{name}' in {sectionName}`)
			result[name] = table.freeze({
				name = spec.name or name,
				sourceKind = "github" :: "github",
				source = spec.source,
				rev = spec.rev,
				target = parseTarget(spec.target, name, sectionName),
				version = spec.version,
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
			assert(
				spec.target == nil,
				`Registry dependency '{name}' in {sectionName} does not support a 'target' field`
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
local function parseManifest(t: unknown, manifestDirectory: string): ProjectManifest
	assert(t ~= nil and typeof(t) == "table", "Expected a table")
	assert(t.package ~= nil and typeof(t.package) == "table", "Expected 'package' field in manifest")

	local pkg = t.package

	assert(
		pkg.name == nil or (typeof(pkg.name) == "string" and #pkg.name > 0),
		"Expected 'name' field in package manifest to be a non-empty string"
	)
	-- FIXME(Luau): Luau currently refines `pkg` to have `version` based on this check, but
	-- also produces a type error for the access _in_ the condition without the cast here.
	assert(
		(pkg :: any).version == nil or (typeof((pkg :: any).version) == "string" and #(pkg :: any).version > 0),
		"Expected 'version' field in package manifest to be a non-empty string"
	)

	local hasName = pkg.name ~= nil
	local hasVersion = (pkg :: any).version ~= nil
	assert(
		hasName == hasVersion,
		"Package manifest must specify both 'name' and 'version', or neither for a virtual package"
	)
	local contentRoot = parseContentRoot((pkg :: any).content_root)
	local files = parseFiles((pkg :: any).files)

	local dependencies = parseDependencyMap((pkg :: any).dependencies, "dependencies", manifestDirectory)
	local devDependencies = parseDependencyMap((pkg :: any).dev_dependencies, "dev_dependencies", manifestDirectory)

	for alias in devDependencies do
		assert(dependencies[alias] == nil, `Alias '{alias}' appears in both dependencies and dev_dependencies`)
	end

	local overrides = parseDependencyMap((t :: any).overrides, "overrides", manifestDirectory)

	local registry: string? = nil
	if (t :: any).registry ~= nil then
		assert(typeof((t :: any).registry) == "string", "Expected 'registry' field to be a string URL")
		registry = (t :: any).registry
	end

	return table.freeze({
		package = table.freeze({
			contentRoot = contentRoot,
			files = files,
			name = pkg.name,
			version = pkg.version,
			dependencies = dependencies,
			devDependencies = devDependencies,
		}),
		overrides = overrides,
		registry = registry,
	})
end

local function parseFile(manifestPath: string): ProjectManifest
	local manifestTable = luau.loadModule(manifestPath)
	return parseManifest(manifestTable, path.dirname(path.format(path.resolve(manifestPath))))
end

local function parseString(contents: string): ProjectManifest
	local manifestTable = luau.load(luau.compile(contents))()
	return parseManifest(manifestTable, ".")
end

return {
	isSourceKind = isSourceKind,
	parseSourceKind = parseSourceKind,
	parseFile = parseFile,
	parseString = parseString,
}
