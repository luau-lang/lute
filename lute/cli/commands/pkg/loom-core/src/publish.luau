-- Publish target selection, validation, and manifest flattening.
local manifest = require("./manifest")
local path = require("@std/path")
local workspace = require("./workspace")

export type PublishTarget = {
	read directory: string,
	read package: manifest.PackageManifest,
	read workspace: workspace.Workspace,
}

local function formatDirectory(directory: path.Pathlike): string
	return path.format(path.resolve(directory))
end

local function isWithinDirectory(directory: string, candidate: string): boolean
	local relative = path.relative(directory, candidate)
	return #relative.parts == 0 or relative.parts[1] ~= ".."
end

local function findMemberByName(resolvedWorkspace: workspace.Workspace, name: string): workspace.Member?
	for _, member in resolvedWorkspace.members do
		if member.name == name then
			return member
		end
	end
	return nil
end

local function findMembersContainingDirectory(
	resolvedWorkspace: workspace.Workspace,
	directory: string
): { workspace.Member }
	local matches: { workspace.Member } = {}
	for _, member in resolvedWorkspace.members do
		if isWithinDirectory(member.directory, directory) then
			table.insert(matches, member)
		end
	end
	return matches
end

local function selectTarget(startDirectory: string, requestedPackage: string?): PublishTarget
	local resolvedWorkspace = workspace.findResolvedRoot(startDirectory)
	local start = formatDirectory(startDirectory)

	if requestedPackage ~= nil then
		local member = findMemberByName(resolvedWorkspace, requestedPackage)
		assert(member ~= nil, `Workspace has no package named '{requestedPackage}'`)
		return table.freeze({
			directory = member.directory,
			package = member.package,
			workspace = resolvedWorkspace,
		})
	end

	if start == resolvedWorkspace.rootDirectory and #resolvedWorkspace.members > 1 then
		error(`Workspace has {#resolvedWorkspace.members} publish targets. Use --package <member-name> to select one.`)
	end

	local matches = findMembersContainingDirectory(resolvedWorkspace, start)
	if #matches == 0 and #resolvedWorkspace.members == 1 then
		matches = { resolvedWorkspace.members[1] }
	end
	assert(#matches > 0, `No publish target found for: {start}`)
	assert(#matches == 1, `Multiple publish targets found for: {start}. Use --package <member-name> to select one.`)

	local member = matches[1]
	return table.freeze({
		directory = member.directory,
		package = member.package,
		workspace = resolvedWorkspace,
	})
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
			manifest.validateDependencyVersionConstraint(dependency.version)
			appendRegistryDependency(lines, indent, alias, dependency)
		else
			assert(
				dependency.version ~= nil,
				`Cannot publish dependency '{alias}': {dependency.sourceKind} dependencies require a version`
			)
			manifest.validateDependencyVersionConstraint(dependency.version)
			appendRegistryDependency(lines, indent, alias, {
				name = dependency.name,
				sourceKind = "registry",
				source = dependency.name,
				version = dependency.version,
			})
		end
	end
end

local function flattenPackage(package: manifest.PackageManifest): string
	manifest.validatePackageVersion(package.version)

	local lines = {
		"return {",
		"\tpackage = {",
		`\t\tname = {quote(package.name)},`,
		`\t\tversion = {quote(package.version)},`,
		"\t\tdependencies = {",
	}
	appendPublishedDependencies(lines, package.dependencies, "\t\t\t")
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t\tdev_dependencies = {")
	appendDevelopmentDependencies(lines, package.devDependencies, "\t\t\t")
	table.insert(lines, "\t\t},")
	table.insert(lines, "\t},")
	table.insert(lines, "}")

	local generatedManifest = table.concat(lines, "\n") .. "\n"
	manifest.parseString(generatedManifest, "generated loom.config.luau")
	return generatedManifest
end

return {
	selectTarget = selectTarget,
	flattenPackage = flattenPackage,
}
