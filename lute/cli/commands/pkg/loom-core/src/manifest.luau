local luau = require("@std/luau")

export type SourceKind =
	| "path"
	| "github"

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

export type DependencySpec =
  | PathDependencySpec
  | GitHubDependencySpec

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

-- TODO: We should do proper error handling because this is user input.
local function parseManifest(t: unknown): ProjectManifest
	assert(t ~= nil and typeof(t) == "table", "Expected a table")
	assert(t.package ~= nil and typeof(t.package) == "table", "Expected 'package' field in manifest")

	local pkg = t.package

	assert(pkg.name ~= nil and typeof(pkg.name) == "string", "Expected 'name' field in package manifest")
	-- FIXME(Luau): Luau currently refines `pkg` to have `version` based on this check, but
	-- also produces a type error for the access _in_ the condition without the cast here.
	assert((pkg :: any).version ~= nil and typeof(pkg.version) == "string", "Expected 'version' field in package manifest")

	local dependencies: { [string]: DependencySpec } = {}
	-- FIXME(Luau): Luau currently refines `pkg` to have `dependencies` based on this check, but
	-- also produces a type error for the access _in_ the condition without the cast here.
	if (pkg :: any).dependencies ~= nil then
		for name, spec in pkg.dependencies do
			assert(
				spec.name == nil or typeof(spec.name) == "string",
				`Optional 'name' field in dependency spec for '{name}' expected to be a string`
			)
			assert(
				isSourceKind(spec.sourceKind),
				`Expected 'sourceKind' to be 'path' or 'github' in dependency spec for '{name}', got '{spec.sourceKind}'`
			)
			assert(
				spec.source ~= nil and typeof(spec.source) == "string",
				`Expected 'source' field in dependency spec for '{name}'`
			)

			if spec.sourceKind == "path" then
				dependencies[name] = table.freeze({
					name = spec.name or name,
					sourceKind = "path",
					source = spec.source,
				}) :: PathDependencySpec
			end

			if spec.sourceKind == "github" then
				assert(typeof(spec.rev) == "string", `Expected 'rev' field for github dependency '{name}'`)
				dependencies[name] = table.freeze({
					name = spec.name or name, -- use the optional name if provided, otherwise use the alias
					sourceKind = "github",
					source = spec.source,
					rev = spec.rev,
				}) :: GitHubDependencySpec
			end
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
