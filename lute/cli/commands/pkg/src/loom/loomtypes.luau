local git = require("./packagesource/git")
export type PackageSource = {
	git: git.Git,
}

export type Loom = {
	install: (self: Loom) -> (),
}

return nil
