local manifest = require("./manifest")
local semver = require("./semver")

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

local function appendSourceDependency(
	lines: { string },
	indent: string,
	alias: string,
	dependency: manifest.PathDependencySpec | manifest.GitHubDependencySpec
)
	table.insert(lines, `{indent}{formatKey(alias)} = \{`)
	if dependency.name ~= alias then
		table.insert(lines, `{indent}\tname = {quote(dependency.name)},`)
	end
	table.insert(lines, `{indent}\tsourceKind = {quote(dependency.sourceKind)},`)
	table.insert(lines, `{indent}\tsource = {quote(dependency.source)},`)
	if dependency.sourceKind == "github" then
		table.insert(lines, `{indent}\trev = {quote(dependency.rev)},`)
	end
	if dependency.version ~= nil then
		table.insert(lines, `{indent}\tversion = {quote(dependency.version)},`)
	end
	table.insert(lines, `{indent}\},`)
end

local function appendDevelopmentDependencies(
	lines: { string },
	dependencies: { [string]: manifest.DependencySpec },
	indent: string
)
	for _, alias in sortedDependencyAliases(dependencies) do
		local dependency = dependencies[alias]
		if dependency.sourceKind == "registry" then
			appendRegistryDependency(lines, indent, alias, dependency)
		else
			appendSourceDependency(lines, indent, alias, dependency)
		end
	end
end

local function appendPublishedDependencies(
	lines: { string },
	dependencies: { [string]: manifest.DependencySpec },
	indent: string
)
	for _, alias in sortedDependencyAliases(dependencies) do
		local dependency = dependencies[alias]
		if dependency.sourceKind == "registry" then
			validateDependencyVersionConstraint(dependency.version)
			appendRegistryDependency(lines, indent, alias, dependency)
		else
			assert(
				dependency.version ~= nil,
				`Cannot publish dependency '{alias}': {dependency.sourceKind} dependencies require a version`
			)
			validateDependencyVersionConstraint(dependency.version)
			appendRegistryDependency(lines, indent, alias, {
				name = dependency.name,
				sourceKind = "registry",
				source = dependency.name,
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
	table.insert(lines, "\t\tdependencies = {")
	appendPublishedDependencies(lines, package.dependencies, "\t\t\t")
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t\tdev_dependencies = {")
	appendDevelopmentDependencies(lines, package.devDependencies, "\t\t\t")
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
