local toml = require("../../extern/toml")

-- export type LockFileDependency = {
-- 	name: string,
-- 	version: string?,
-- 	source_kind: string?,
-- 	source: string?,
-- }

-- TODO: Support path/registry dependencies
export type LockFilePackage = {
	name: string,
	rev: string,
	source_kind: string,
	source: string,
	-- dependencies: { LockFileDependency },
}

export type LockFile = {
	version: number,
	package: { LockFilePackage },
}

function parse(content: string): LockFile
	local lockFile = toml.deserialize(content) :: any
	return lockFile :: LockFile
end

return {
	parse = parse,
}
