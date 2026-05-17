--!strict

local parser = require("@self/parser")
local solver = require("@self/solver")

export type PrereleaseId = parser.PrereleaseId
export type Version = parser.Version
export type Comparator = parser.Comparator
export type Constraint = parser.Constraint

export type PackageVersion = solver.PackageVersion
export type Requirement = solver.Requirement
export type Universe = solver.Universe
export type Resolution = solver.Resolution

return {
	parse = parser.parse,
	tryParse = parser.tryParse,
	parseConstraint = parser.parseConstraint,
	satisfies = parser.satisfies,
	compare = parser.compare,
	sort = parser.sort,
	format = parser.format,
	formatConstraint = parser.formatConstraint,

	solve = solver.solve,
}
