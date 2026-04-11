local luau = require("@std/luau")

export type LockFilePackage = {
	name: string,
	rev: string,
	source: string,
	sourceKind: string,
	installPath: string,
	dependencies: { [string]: string },
}

export type LockFile = {
	version: number,
	packages: { string },
	dependencies: { [string]: LockFilePackage },
}

local function validatePackageEntry(key: string, entry: any)
	assert(type(entry) == "table", `Expected table for dependency '{key}'`)
	assert(type(entry.name) == "string", `Expected 'name' field in dependency '{key}'`)
	assert(type(entry.rev) == "string", `Expected 'rev' field in dependency '{key}'`)
	assert(type(entry.source) == "string", `Expected 'source' field in dependency '{key}'`)
	assert(type(entry.sourceKind) == "string", `Expected 'sourceKind' field in dependency '{key}'`)
	assert(type(entry.installPath) == "string", `Expected 'installPath' field in dependency '{key}'`)
	assert(type(entry.dependencies) == "table", `Expected 'dependencies' field in dependency '{key}'`)
	for alias, depKey in entry.dependencies do
		assert(type(alias) == "string", `Expected alias to be a string for dependency '{key}'`)
		assert(type(depKey) == "string", `Expected dependency key to be a string for dependency '{key}'`)
	end
end

local function parseTable(t: any): LockFile
	assert(t ~= nil and type(t) == "table", "Expected lockfile to be a table")
	assert(t.version == 2, `Unsupported lockfile version: {t.version}`)
	assert(type(t.packages) == "table", "Expected 'packages' field in lockfile")
	assert(type(t.dependencies) == "table", "Expected 'dependencies' field in lockfile")

	local dependencies = t.dependencies :: { [unknown]: unknown }

	for _, key in t.packages do
		assert(type(key) == "string", "Expected package key to be a string")
		assert(dependencies[key] ~= nil, `Package '{key}' not found in dependencies`)
	end

	for key, entry in dependencies do
		assert(type(key) == "string", "Expected package key to be a string")
		validatePackageEntry(key, entry)
	end

	return t
end

local function parseFile(lockfilePath: string): LockFile
	local t = luau.loadModule(lockfilePath)
	return parseTable(t)
end

return {
	parseFile = parseFile,
}
