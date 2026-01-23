-- export type LockFileDependency = {
-- 	name: string,
-- 	version: string?,
-- 	sourceKind: string?,
-- 	source: string?,
-- }

-- TODO: Support path/registry dependencies
export type LockFilePackage = {
	name: string,
	rev: string,
	sourceKind: string,
	source: string,
	-- dependencies: { LockFileDependency },
}

export type LockFile = {
	version: number,
	package: { LockFilePackage },
}

return {}
