local Git = require("./package_source/git")
export type package_source = {
	git: Git.git,
}

export type loom = {
	install: (self: loom) -> (),
}

return nil
