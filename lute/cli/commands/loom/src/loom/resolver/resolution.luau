local package = require("./package")
local lockfile = require("../lockfile/lockfile")
local project_manifest = require("../manifest/project_manifest")

type Resolution = {
	packages: { package.Package },
}

function fromLockfile(lockfile: lockfile.LockFile): Resolution
	local packages = {}
	for _, lockfilePackage in lockfile.package do
		table.insert(packages, package.fromLockPackage(lockfilePackage))
	end
	return { packages = packages }
end

function fromManifest(manifest: project_manifest.ProjectManifest): Resolution
	local dependencies = manifest.package.dependencies
	local packages = {}
	for name, spec in dependencies do
		table.insert(packages, package.fromDependencySpec(name, spec))
	end
	return { packages = packages }
end

function toLockFile(resolution: Resolution): lockfile.LockFile
	local lockfilePackages = {}
	for _, pkg in resolution.packages do
		table.insert(lockfilePackages, {
			name = pkg.name,
			rev = pkg.rev,
			source_kind = pkg.source_kind,
			source = pkg.source,
		})
	end
	return {
		version = 1,
		package = lockfilePackages,
	}
end

return {
	fromLockfile = fromLockfile,
	fromManifest = fromManifest,
	toLockFile = toLockFile,
}
