local lockfile = require("./lockfile")

function testReadLockfileSingleGitPackageNoDependencies()
	local lockfile_content = [=[version = 1
[[package]]
name = "lockfile_single_package"
rev = "v0.1.0"
source_kind = "git"
source = "https://github.com/user/repo?rev=abcdef1234567890"]=]
	local lockFile = lockfile.parse(lockfile_content)

	assert(lockFile.version == 1, "Expected lock file version to be 1")
	assert(#lockFile.package == 1, "Expected exactly one package in the lock file")

	assert(lockFile.package[1].name == "lockfile_single_package", "Unexpected package name")
	assert(lockFile.package[1].rev == "v0.1.0", "Unexpected package version")
	assert(lockFile.package[1].source_kind == "git", "Unexpected package source kind")
	assert(
		lockFile.package[1].source == "https://github.com/user/repo?rev=abcdef1234567890",
		"Unexpected package source"
	)
end

function testReadLockfileMultiplePackagesMultipleDependencies()
	local lockfile_content = [=[version = 1
[[package]]
name = "package_one"
rev = "v1.0.0"
source_kind = "git"
source = "https://github.com/user/repo?rev=abcdef1234567890"

[[package]]
name = "package_two"
rev = "v2.0.0"
source_kind = "git"
source = "https://github.com/user/repo?rev=abcdef1234567890"

[[package]]
name = "package_three"
rev = "v3.0.0"
source_kind = "git"
source = "https://github.com/user/repo?rev=abcdef1234567890"]=]

	local lockFile = lockfile.parse(lockfile_content)

	assert(lockFile.version == 1, "Expected lock file version to be 1")
	assert(#lockFile.package == 3, "Expected exactly three packages in the lock file")

	local expected_packages = {
		{
			name = "package_one",
			rev = "v1.0.0",
			source_kind = "git",
			source = "https://github.com/user/repo?rev=abcdef1234567890",
		},
		{
			name = "package_two",
			rev = "v2.0.0",
			source_kind = "git",
			source = "https://github.com/user/repo?rev=abcdef1234567890",
		},
		{
			name = "package_three",
			rev = "v3.0.0",
			source_kind = "git",
			source = "https://github.com/user/repo?rev=abcdef1234567890",
		},
	}

	for i, expected in expected_packages do
		local pkg = lockFile.package[i]
		assert(pkg.name == expected.name, `Unexpected package name for package {expected.name}`)
		assert(pkg.rev == expected.rev, `Unexpected package version for package {expected.name}`)
		assert(pkg.source_kind == expected.source_kind, `Unexpected source kind for package {expected.name}`)
		assert(pkg.source == expected.source, `Unexpected source for package {expected.name}`)
	end
end

testReadLockfileSingleGitPackageNoDependencies()
testReadLockfileMultiplePackagesMultipleDependencies()
