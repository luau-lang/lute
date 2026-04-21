local luau = require("@std/luau")

export type LockfileDependency = {
	read name: string,
	read rev: string?,
	read source: string,
	read sourceKind: string,
	read installPath: string,
	read dependencies: { [string]: string },
}

export type LockfileMember = {
	read path: string,
	read dependencies: { [string]: string },
}

export type Lockfile = {
	read version: number,
	read packages: { [string]: LockfileDependency },
	read dependencies: { [string]: string },
}

local function validatePackageEntry(key: string, entry: any)
	assert(type(entry) == "table", `Expected table for dependency '{key}'`)
	assert(type(entry.name) == "string", `Expected 'name' field in dependency '{key}'`)
	assert(
		entry.rev == nil or type(entry.rev) == "string",
		`Expected 'rev' field to be a string or nil for dependency '{key}'`
	)
	assert(type(entry.source) == "string", `Expected 'source' field in dependency '{key}'`)
	assert(type(entry.sourceKind) == "string", `Expected 'sourceKind' field in dependency '{key}'`)
	assert(type(entry.installPath) == "string", `Expected 'installPath' field in dependency '{key}'`)
	assert(type(entry.dependencies) == "table", `Expected 'dependencies' field in dependency '{key}'`)
	for alias, depKey in entry.dependencies do
		assert(type(alias) == "string", `Expected alias to be a string for dependency '{key}'`)
		assert(type(depKey) == "string", `Expected dependency key to be a string for dependency '{key}'`)
	end
	table.freeze(entry.dependencies)
end

local function parseLockfile(t: any): Lockfile
	assert(t ~= nil and type(t) == "table", "Expected lockfile to be a table")
	assert(t.version == 3, `Unsupported lockfile version: {t.version}`)
	assert(type(t.packages) == "table", "Expected 'packages' field in lockfile")
	assert(type(t.dependencies) == "table", "Expected 'dependencies' field in lockfile")

	for key, entry in t.packages do
		assert(type(key) == "string", "Expected package key to be a string")
		validatePackageEntry(key, entry)
	end
	table.freeze(t.packages)

	for alias, key in t.dependencies do
		assert(type(alias) == "string", "Expected dependency alias to be a string")
		assert(type(key) == "string", "Expected dependency key to be a string")
		assert(t.packages[key] ~= nil, `Dependency '{alias}' references package '{key}' which is not in packages`)
	end
	table.freeze(t.dependencies)

	if t.members ~= nil then
		assert(type(t.members) == "table", "Expected 'members' field to be a table")
		for memberName, member in t.members do
			assert(type(memberName) == "string", "Expected member name to be a string")
			assert(type(member) == "table", `Expected table for member '{memberName}'`)
			assert(type(member.path) == "string", `Expected 'path' field in member '{memberName}'`)
			assert(
				type((member :: { [string]: unknown }).dependencies) == "table",
				`Expected 'dependencies' field in member '{memberName}'`
			)
			for alias, depKey in member.dependencies do
				assert(type(alias) == "string", `Expected alias to be a string in member '{memberName}'`)
				assert(type(depKey) == "string", `Expected dependency key to be a string in member '{memberName}'`)
				assert(
					(t.dependencies :: { [string]: unknown })[depKey] ~= nil,
					`Dependency '{depKey}' in member '{memberName}' not found in dependencies`
				)
			end
			table.freeze(member.dependencies)
		end
		table.freeze(t.members)
	end

	return table.freeze(t)
end

local function parseFile(lockfilePath: string): Lockfile
	local t = luau.loadModule(lockfilePath)
	return parseLockfile(t)
end

return {
	parseFile = parseFile,
}
