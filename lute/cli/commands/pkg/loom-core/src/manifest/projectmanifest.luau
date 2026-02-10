-- TODO: Support path/registry dependencies
export type DependencySpec = {
	rev: string,
	sourceKind: string,
	source: string,
}

export type PackageManifest = {
	name: string,
	version: string,
	dependencies: { [string]: DependencySpec },
}
--[[
{
	"name": "MyPackage",
	"version": "1.0.0",
	"dependencies": {
		"OtherPackage": "1.0.0",
	}
}
]]

export type ProjectManifest = {
	package: PackageManifest,
}

-- FIXME(Luau): running into issues with getting this to type check properly.
-- We also should also do proper error handling because this is user input.
function fromTable(table: any): ProjectManifest
	assert(table.package ~= nil and type(table.package) == "table", "Expected 'package' field in manifest")

	local package = table.package

	assert(package.name ~= nil and type(package.name) == "string", "Expected 'name' field in package manifest")
	assert(package.version ~= nil and type(package.version) == "string", "Expected 'rev' field in package manifest")
	if package.dependencies ~= nil then
		local dependencies = package.dependencies
		for _, spec in dependencies do
			assert(spec.rev ~= nil and type(spec.rev) == "string", "Expected 'rev' field in dependency spec")
			assert(
				spec.sourceKind ~= nil and type(spec.sourceKind) == "string",
				"Expected 'sourceKind' field in dependency spec"
			)
			assert(spec.source ~= nil and type(spec.source) == "string", "Expected 'source' field in dependency spec")
		end
	end

	return table
end

return {
	fromTable = fromTable,
}
