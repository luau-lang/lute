local lockfile = require("../lockfile/lockfile")
local manifest = require("../manifest/project_manifest")
export type Package = {
	name: string,
	rev: string,
	source_kind: string,
	source: string,
}

local function fromLockPackage(lockPackage: lockfile.LockFilePackage): Package
	return {
		name = lockPackage.name,
		rev = lockPackage.rev,
		source_kind = lockPackage.source_kind,
		source = lockPackage.source,
	}
end

local function fromDependencySpec(name: string, spec: manifest.DependencySpec): Package
	if spec.source_kind == "git" then
		local source = spec.source .. "/archive/" .. spec.rev .. ".zip"
		return {
			name = name,
			rev = spec.rev,
			source_kind = spec.source_kind,
			source = source,
		}
	else
		error(`Unsupported source kind: {spec.source_kind} for package {name}`)
	end
end

return {
	fromLockPackage = fromLockPackage,
	fromDependencySpec = fromDependencySpec,
}
