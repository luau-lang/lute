local test = require("@std/test")
local parser = require("@commands/pkg/loom-core/src/semver/parser")
local solver = require("@commands/pkg/loom-core/src/semver/solver")

local function namedVersion(
	name: string,
	vstr: string,
	deps: { [string]: solver.Requirement }?
): solver.PackageVersion
	local v = parser.parse(vstr)
	return table.freeze({
		name = name,
		version = v,
		versionString = parser.format(v),
		dependencies = table.freeze(deps or {}),
	})
end

local function req(name: string, constraintStr: string, requiredBy: string?): solver.Requirement
	return table.freeze({
		name = name,
		constraint = parser.parseConstraint(constraintStr),
		requiredBy = requiredBy,
	})
end

test.suite("solver.solve", function(suite)
	suite:case("singlePackage", function(assert)
		local universe: solver.Universe = {
			lemon = {
				namedVersion("lemon", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			lemon = req("lemon", "^1.0.0"),
		})
		assert.neq(resolution.lemon, nil)
		assert.eq(resolution.lemon.versionString, "1.0.0")
	end)

	suite:case("picksHighestSatisfying", function(assert)
		local universe: solver.Universe = {
			lemon = {
				namedVersion("lemon", "1.3.0"),
				namedVersion("lemon", "1.2.0"),
				namedVersion("lemon", "1.1.0"),
				namedVersion("lemon", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			lemon = req("lemon", "^1.0.0"),
		})
		assert.eq(resolution.lemon.versionString, "1.3.0")
	end)

	suite:case("multiplePackagesNoConflict", function(assert)
		local universe: solver.Universe = {
			lemon = { namedVersion("lemon", "1.3.0"), namedVersion("lemon", "1.0.0") },
			lime = { namedVersion("lime", "0.5.1"), namedVersion("lime", "0.4.0") },
		}
		local resolution = solver.solve(universe, {
			lemon = req("lemon", "^1.0.0"),
			lime = req("lime", ">=0.5.0"),
		})
		assert.eq(resolution.lemon.versionString, "1.3.0")
		assert.eq(resolution.lime.versionString, "0.5.1")
	end)

	suite:case("diamondDependency", function(assert)
		-- app -> lemon ^1.0.0, lime ^0.5.0
		-- lemon 1.3.0 -> citrus ^1.0.0
		-- lime 0.5.1  -> citrus ^1.2.0
		-- should resolve citrus to 1.2.x-compatible version (e.g. 1.5.0)
		local universe: solver.Universe = {
			lemon = {
				namedVersion("lemon", "1.3.0", { citrus = req("citrus", "^1.0.0") }),
			},
			lime = {
				namedVersion("lime", "0.5.1", { citrus = req("citrus", "^1.2.0") }),
			},
			citrus = {
				namedVersion("citrus", "1.5.0"),
				namedVersion("citrus", "1.2.0"),
				namedVersion("citrus", "1.1.0"),
				namedVersion("citrus", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			lemon = req("lemon", "^1.0.0"),
			lime = req("lime", "^0.5.0"),
		})
		assert.neq(resolution.citrus, nil)
		-- Must satisfy both ^1.0.0 and ^1.2.0
		assert.that(parser.satisfies(resolution.citrus.version, parser.parseConstraint("^1.0.0")))
		assert.that(parser.satisfies(resolution.citrus.version, parser.parseConstraint("^1.2.0")))
		assert.eq(resolution.citrus.versionString, "1.5.0")
	end)

	suite:case("constraintUpgrade", function(assert)
		-- A requires ^1.0.0, B requires ^1.5.0
		-- Initial pick for A would be 1.3.0, but B pushes it to 1.5.0 which also satisfies A
		-- a 1.0.0 needs shared ^1.0.0, b 1.0.0 needs shared ^1.5.0
		-- We need to process both and end up at shared 1.5.0
		local universeWithDeps: solver.Universe = {
			a = {
				namedVersion("a", "1.0.0", { shared = req("shared", "^1.0.0") }),
			},
			b = {
				namedVersion("b", "1.0.0", { shared = req("shared", "^1.5.0") }),
			},
			shared = {
				namedVersion("shared", "1.5.0"),
				namedVersion("shared", "1.3.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universeWithDeps, {
			a = req("a", "^1.0.0"),
			b = req("b", "^1.0.0"),
		})
		assert.eq(resolution.shared.versionString, "1.5.0")
	end)

	suite:case("transitiveDepResolved", function(assert)
		-- app -> parent -> child
		local universe: solver.Universe = {
			parent = {
				namedVersion("parent", "1.0.0", { child = req("child", "^2.0.0") }),
			},
			child = {
				namedVersion("child", "2.1.0"),
				namedVersion("child", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			parent = req("parent", "^1.0.0"),
		})
		assert.neq(resolution.child, nil)
		assert.eq(resolution.child.versionString, "2.1.0")
	end)

	suite:case("trueConflictErrors", function(assert)
		-- ^1.0.0 AND ^2.0.0 can never both be satisfied
		local universe: solver.Universe = {
			conflict = {
				namedVersion("conflict", "2.0.0"),
				namedVersion("conflict", "1.0.0"),
			},
		}
		assert.throws(function()
			solver.solve(universe, {
				v1 = req("conflict", "^1.0.0"),
				v2 = req("conflict", "^2.0.0"),
			})
		end)
	end)

	suite:case("unknownPackageErrors", function(assert)
		local universe: solver.Universe = {}
		assert.throws(function()
			solver.solve(universe, {
				lemon = req("lemon", "^1.0.0"),
			})
		end)
	end)

	suite:case("conflictErrorListsConstrainers", function(assert)
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "1.0.0"),
			},
		}
		-- ^1.0.0 and ^2.0.0 conflict; error should mention both.
		-- ^X.0.0 expands to ">=X.0.0 <X+1.0.0" so we match those substrings.
		local ok, err = pcall(function()
			solver.solve(universe, {
				a = req("pkg", "^1.0.0", "root"),
				b = req("pkg", "^2.0.0", "root"),
			})
		end)
		assert.eq(ok, false)
		local errStr = tostring(err)
		assert.strContains(errStr, ">=1.0.0")
		assert.strContains(errStr, ">=2.0.0")
	end)

	suite:case("deduplicatesSameRequirement", function(assert)
		-- Two roots ask for the same package with compatible constraints; should not duplicate
		local universe: solver.Universe = {
			shared = {
				namedVersion("shared", "1.2.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			a = req("shared", "^1.0.0"),
			b = req("shared", ">=1.1.0"),
		})
		-- Only one entry for "shared"
		local count = 0
		for _ in resolution do
			count += 1
		end
		assert.eq(count, 1)
		assert.eq(resolution.shared.versionString, "1.2.0")
	end)

	suite:case("constraintRetraction", function(assert)
		-- Exercises the retraction code path:
		-- root requires pkga >=1.0.0 (allows 2.x) and pkgb ^1.0.0.
		-- pkga 2.0.0 requires pkgc <2.0.0 — solver picks this first (newest).
		-- pkgb 1.0.0 requires pkgc ^3.0.0 (>=3.0.0 <4.0.0).
		-- pkgc now has <2.0.0 AND >=3.0.0 — unsatisfiable.
		-- pkgb also requires pkga <2.0.0, forcing pkga to downgrade to 1.0.0.
		-- pkga 1.0.0's old constraint (<2.0.0 on pkgc) is retracted; new constraint is <4.0.0.
		-- pkgc now only has >=3.0.0 <4.0.0, resolving to 3.0.0.
		local universe: solver.Universe = {
			pkga = {
				namedVersion("pkga", "2.0.0", { pkgc = req("pkgc", "<2.0.0") }),
				namedVersion("pkga", "1.0.0", { pkgc = req("pkgc", "<4.0.0") }),
			},
			pkgb = {
				namedVersion("pkgb", "1.0.0", {
					pkgc = req("pkgc", "^3.0.0"),
					pkga = req("pkga", "<2.0.0"),
				}),
			},
			pkgc = {
				namedVersion("pkgc", "3.0.0"),
				namedVersion("pkgc", "1.5.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkga = req("pkga", ">=1.0.0"),
			pkgb = req("pkgb", "^1.0.0"),
		})
		-- pkga must have downgraded to 1.0.0 so its old pkgc <2.0.0 constraint is retracted
		assert.eq(resolution.pkga.versionString, "1.0.0")
		assert.eq(resolution.pkgb.versionString, "1.0.0")
		assert.eq(resolution.pkgc.versionString, "3.0.0")
	end)
end)
