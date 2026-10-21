local fs = require("@std/fs")
local github = require("./github")
local manifest = require("./manifest")
local path = require("@std/path")
local semver = require("./semver")
local store = require("./store")

local function validatePackageVersion(version: string): semver.Version
	local parsed = semver.tryParse(version)
	assert(parsed ~= nil, `Invalid package version: '{version}'`)
	return parsed
end

local function validateDependencyVersionConstraint(version: string): semver.Constraint
	local ok, constraint = pcall(semver.parseConstraint, version)
	assert(ok, `Invalid dependency version constraint: '{version}'`)
	return constraint :: semver.Constraint
end

local function quote(value: string): string
	return string.format("%q", value)
end

local function formatKey(key: string): string
	return `[{quote(key)}]`
end

local function sortedDependencyAliases(dependencies: { [string]: manifest.DependencySpec }): { string }
	local aliases: { string } = {}
	for alias in dependencies do
		table.insert(aliases, alias)
	end
	table.sort(aliases)
	return aliases
end

local function appendRegistryDependency(
	lines: { string },
	indent: string,
	alias: string,
	dependency: manifest.RegistryDependencySpec
)
	table.insert(lines, `{indent}{formatKey(alias)} = \{`)
	table.insert(lines, `{indent}\tsourceKind = "registry",`)
	table.insert(lines, `{indent}\tsource = {quote(dependency.source)},`)
	table.insert(lines, `{indent}\tversion = {quote(dependency.version)},`)
	table.insert(lines, `{indent}\},`)
end

local function getSourcePackageDirectory(
	dependency: manifest.PathDependencySpec | manifest.GitHubDependencySpec
): string
	if dependency.sourceKind == "path" then
		return dependency.directory
	end

	store.ensureStoreDirectory()
	local key = store.getGitHubCheckoutKey(dependency.source, dependency.rev)
	local checkoutDirectory = store.getPackagePath(key)
	if not store.hasPackage(key) then
		github.installPackage(dependency.source, dependency.rev, checkoutDirectory)
	end

	if dependency.target == nil then
		return checkoutDirectory
	end

	return path.format(path.resolve(checkoutDirectory, dependency.target))
end

local function getSourcePackageName(
	alias: string,
	dependency: manifest.PathDependencySpec | manifest.GitHubDependencySpec
): string
	local directory = getSourcePackageDirectory(dependency)
	local manifestPath = path.format(path.join(directory, "loom.config.luau"))
	assert(fs.exists(manifestPath), `Cannot publish dependency '{alias}': package manifest not found: {manifestPath}`)

	local sourceManifest = manifest.parseFile(manifestPath)
	assert(sourceManifest.package.name ~= nil, `Cannot publish dependency '{alias}': target package must have a name`)
	return sourceManifest.package.name
end

local function appendDependencies(
	lines: { string },
	dependencies: { [string]: manifest.DependencySpec },
	indent: string,
	isDevDependency: boolean
)
	for _, alias in sortedDependencyAliases(dependencies) do
		local dependency = dependencies[alias]
		if dependency.sourceKind == "registry" then
			validateDependencyVersionConstraint(dependency.version)
			appendRegistryDependency(lines, indent, alias, dependency)
		else
			if dependency.version == nil then
				if isDevDependency then
					continue
				end
				error(`Cannot publish dependency '{alias}': {dependency.sourceKind} dependencies require a version`)
			end
			validateDependencyVersionConstraint(dependency.version)
			local sourcePackageName = getSourcePackageName(alias, dependency)
			appendRegistryDependency(lines, indent, alias, {
				name = sourcePackageName,
				sourceKind = "registry",
				source = sourcePackageName,
				version = dependency.version,
			})
		end
	end
end

local function flattenPackage(package: manifest.PackageManifest, registry: string?): string
	assert(
		package.name ~= nil and package.version ~= nil,
		"Cannot publish a virtual package: package name and version are required"
	)
	local name = package.name :: string
	local version = package.version :: string
	validatePackageVersion(version)

	local lines = {
		"return {",
		"\tpackage = {",
		`\t\tname = {quote(name)},`,
		`\t\tversion = {quote(version)},`,
	}
	if package.license ~= nil then
		table.insert(lines, `\t\tlicense = {quote(package.license)},`)
	end
	table.insert(lines, "\t\tdependencies = {")
	appendDependencies(lines, package.dependencies, "\t\t\t", false)
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t\tdev_dependencies = {")
	appendDependencies(lines, package.devDependencies, "\t\t\t", true)
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t},")
	if registry ~= nil then
		table.insert(lines, `\tregistry = {quote(registry)},`)
	end
	table.insert(lines, "}")

	local generatedManifest = table.concat(lines, "\n") .. "\n"
	manifest.parseString(generatedManifest)
	return generatedManifest
end

return {
	flattenPackage = flattenPackage,
}
