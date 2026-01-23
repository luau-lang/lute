local lockfile = require("../lockfile/lockfile")
local manifest = require("../manifest/projectmanifest")
export type Package = {
	name: string,
	rev: string,
	sourceKind: string,
	source: string,
}

local function fromLockPackage(lockPackage: lockfile.LockFilePackage): Package
	return {
		name = lockPackage.name,
		rev = lockPackage.rev,
		sourceKind = lockPackage.sourceKind,
		source = lockPackage.source,
	}
end

local function fromDependencySpec(name: string, spec: manifest.DependencySpec): Package
	if spec.sourceKind == "github" then
		local source = spec.source .. "/archive/" .. spec.rev .. ".zip"
		return {
			name = name,
			rev = spec.rev,
			sourceKind = spec.sourceKind,
			source = source,
		}
	else
		error(`Unsupported source kind: {spec.sourceKind} for package {name}`)
	end
end

return {
	fromLockPackage = fromLockPackage,
	fromDependencySpec = fromDependencySpec,
}
