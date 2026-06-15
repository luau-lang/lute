local test = require("@std/test")
local parser = require("@commands/pkg/loom-core/src/semver/parser")
local solver = require("@commands/pkg/loom-core/src/semver/solver")

local function namedVersion(name: string, vstr: string, deps: { [string]: solver.Requirement }?): solver.PackageVersion
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

		assert.neq(resolution["lemon@1"], nil)
		assert.eq(resolution["lemon@1"].versionString, "1.0.0")
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

		assert.eq(resolution["lemon@1"].versionString, "1.3.0")
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

		assert.eq(resolution["lemon@1"].versionString, "1.3.0")
		assert.eq(resolution["lime@0.5"].versionString, "0.5.1")
	end)

	suite:case("diamondDependency", function(assert)
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

		assert.neq(resolution["citrus@1"], nil)
		assert.that(parser.satisfies(resolution["citrus@1"].version, parser.parseConstraint("^1.0.0")))
		assert.that(parser.satisfies(resolution["citrus@1"].version, parser.parseConstraint("^1.2.0")))
		assert.eq(resolution["citrus@1"].versionString, "1.5.0")
	end)

	suite:case("constraintUpgrade", function(assert)
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
		assert.eq(resolution["shared@1"].versionString, "1.5.0")
	end)

	suite:case("transitiveDepResolved", function(assert)
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
		assert.neq(resolution["child@2"], nil)
		assert.eq(resolution["child@2"].versionString, "2.1.0")
	end)

	suite:case("sameSlotConflictErrors", function(assert)
		-- ^1.5.0 and <1.3.0 are in the same slot but incompatible
		local universe: solver.Universe = {
			conflict = {
				namedVersion("conflict", "1.5.0"),
				namedVersion("conflict", "1.2.0"),
			},
		}
		local ok, err = pcall(function()
			solver.solve(universe, {
				v1 = req("conflict", "^1.5.0"),
				v2 = req("conflict", ">=1.0.0 <1.3.0"),
			})
		end)
		assert.eq(ok, false)
		local errStr = tostring(err)
		assert.strContains(errStr, "version conflict for 'conflict'")
	end)

	suite:case("multiMajorCoexistence", function(assert)
		-- ^1.0.0 and ^2.0.0 go into different slots and both resolve
		local universe: solver.Universe = {
			shared = {
				namedVersion("shared", "2.0.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			v1 = req("shared", "^1.0.0"),
			v2 = req("shared", "^2.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.0.0")
		assert.eq(resolution["shared@2"].versionString, "2.0.0")
	end)

	suite:case("unknownPackageErrors", function(assert)
		local universe: solver.Universe = {}
		assert.throwsWith("unknown package 'lemon': not found in universe", function()
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
		-- ^1.5.0 and <1.1.0 in the same slot; error should mention both.
		local ok, err = pcall(function()
			solver.solve(universe, {
				a = req("pkg", "^1.5.0", "root"),
				b = req("pkg", ">=1.0.0 <1.1.0", "root"),
			})
		end)

		assert.eq(ok, false)
		local errStr = tostring(err)
		assert.strContains(errStr, ">=1.5.0")
		assert.strContains(errStr, "<1.1.0")
	end)

	suite:case("deduplicatesSameRequirement", function(assert)
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

		-- Only one slot entry for shared@1
		local count = 0
		for _ in resolution do
			count += 1
		end

		assert.eq(count, 1)
		assert.eq(resolution["shared@1"].versionString, "1.2.0")
	end)

	suite:case("multiMajorFromTransitiveDeps", function(assert)
		-- parent has deps on both shared ^1.0.0 and shared ^2.0.0
		-- Under multi-major, both slots are resolved
		local universe: solver.Universe = {
			parent = {
				namedVersion("parent", "1.0.0", {
					sharedV1 = req("shared", "^1.0.0"),
					sharedV2 = req("shared", "^2.0.0"),
				}),
			},
			shared = {
				namedVersion("shared", "2.0.0"),
				namedVersion("shared", "1.0.0"),
			},
		}

		local resolution = solver.solve(universe, {
			parent = req("parent", "^1.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.0.0")
		assert.eq(resolution["shared@2"].versionString, "2.0.0")
	end)

	suite:case("circularDependencyErrors", function(assert)
		local universe: solver.Universe = {
			a = {
				namedVersion("a", "1.0.0", { b = req("b", "^1.0.0") }),
			},
			b = {
				namedVersion("b", "1.0.0", { a = req("a", "^1.0.0") }),
			},
		}

		assert.throwsWith("circular dependency: a@1 -> b@1 -> a@1", function()
			solver.solve(universe, {
				a = req("a", "^1.0.0"),
			})
		end)
	end)

	suite:case("backtracksWithinSameSlot", function(assert)
		-- A@1.1.0 and B@1.0.0 both need shared in slot @1, but:
		-- A@1.1.0 needs shared ^1.5.0, B needs shared ^1.0.0 <1.3.0
		-- These conflict within the same slot. Solver must backtrack A to 1.0.0
		-- (which needs shared ^1.0.0) so shared@1 can satisfy both at 1.2.0.
		local universe: solver.Universe = {
			A = {
				namedVersion("A", "1.1.0", { shared = req("shared", "^1.5.0") }),
				namedVersion("A", "1.0.0", { shared = req("shared", "^1.0.0") }),
			},
			B = {
				namedVersion("B", "1.0.0", { shared = req("shared", ">=1.0.0 <1.3.0") }),
			},
			shared = {
				namedVersion("shared", "1.5.0"),
				namedVersion("shared", "1.2.0"),
				namedVersion("shared", "1.0.0"),
			},
		}

		local resolution = solver.solve(universe, {
			A = req("A", "^1.0.0"),
			B = req("B", "^1.0.0"),
		})

		assert.eq(resolution["A@1"].versionString, "1.0.0")
		assert.eq(resolution["B@1"].versionString, "1.0.0")
		assert.eq(resolution["shared@1"].versionString, "1.2.0")
	end)

	suite:case("backtracksOnDeepTransitiveFailure", function(assert)
		local universe: solver.Universe = {
			X = {
				namedVersion("X", "1.1.0", { Y = req("Y", "^2.0.0") }),
				namedVersion("X", "1.0.0", { Y = req("Y", "^1.0.0") }),
			},
			Y = {
				namedVersion("Y", "2.0.0", { Z = req("Z", "^5.0.0") }),
				namedVersion("Y", "1.0.0"),
			},
			Z = {
				namedVersion("Z", "1.0.0"),
			},
		}

		local resolution = solver.solve(universe, {
			X = req("X", "^1.0.0"),
		})

		assert.eq(resolution["X@1"].versionString, "1.0.0")
		assert.eq(resolution["Y@1"].versionString, "1.0.0")
		assert.eq(resolution["Z@5"], nil)
	end)

	suite:case("handlesDeepDependencyChain", function(assert)
		local universe: solver.Universe = {}
		for i = 1, 100 do
			local name = `p{i}`
			local deps: { [string]: solver.Requirement } = {}
			if i < 100 then
				deps[`p{i + 1}`] = req(`p{i + 1}`, "^1.0.0")
			end
			universe[name] = { namedVersion(name, "1.0.0", deps) }
		end

		local resolution = solver.solve(universe, {
			p1 = req("p1", "^1.0.0"),
		})
		assert.eq(resolution["p1@1"].versionString, "1.0.0")
		assert.eq(resolution["p100@1"].versionString, "1.0.0")
	end)

	suite:case("reportsShallowConflict", function(assert)
		local universe: solver.Universe = {
			A = {
				namedVersion("A", "2.0.0", { deep = req("deep", "^1.0.0") }),
				namedVersion("A", "1.0.0", { deep = req("deep", "^1.0.0") }),
			},
			deep = {
				namedVersion("deep", "1.0.0", { core = req("core", "^3.0.0") }),
			},
			core = {
				namedVersion("core", "2.0.0"),
			},
		}
		local ok, err = pcall(function()
			solver.solve(universe, {
				A = req("A", "^1.0.0"),
				core = req("core", "^2.0.0"),
			})
		end)
		assert.eq(ok, false)
		assert.strContains(tostring(err), "version conflict for 'core'")
	end)

	suite:case("mrvPicksMostConstrainedFirst", function(assert)
		-- 'forced' has exactly 1 satisfying candidate (=1.0.0) which depends on lib ^1.2.0.
		-- 'flexible' has many candidates, and its latest (1.10.0) depends on lib ^1.0.0.
		-- If MRV picks 'forced' first, lib gets constrained to ^1.2.0 early.
		-- Then 'flexible' picks 1.10.0 whose lib ^1.0.0 merges into the same slot —
		-- lib resolves to 1.5.0 (satisfies both ^1.2.0 and ^1.0.0).
		-- If MRV were broken and picked 'flexible' first, the result would be the same
		-- but would explore more branches. We verify the outcome is correct.
		local universe: solver.Universe = {
			forced = {
				namedVersion("forced", "1.0.0", { lib = req("lib", "^1.2.0") }),
			},
			flexible = {},
			lib = {
				namedVersion("lib", "1.5.0"),
				namedVersion("lib", "1.2.0"),
				namedVersion("lib", "1.0.0"),
			},
		}
		for i = 10, 1, -1 do
			table.insert(universe.flexible, namedVersion("flexible", `1.{i}.0`, { lib = req("lib", "^1.0.0") }))
		end

		local resolution = solver.solve(universe, {
			forced = req("forced", "=1.0.0"),
			flexible = req("flexible", "^1.0.0"),
		})
		assert.eq(resolution["forced@1"].versionString, "1.0.0")
		assert.eq(resolution["flexible@1"].versionString, "1.10.0")
		-- lib must satisfy both ^1.2.0 (from forced) and ^1.0.0 (from flexible)
		assert.eq(resolution["lib@1"].versionString, "1.5.0")
	end)

	suite:case("prereleaseExcludedByStableConstraint", function(assert)
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "1.1.0-alpha"),
				namedVersion("pkg", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "^1.0.0"),
		})
		assert.eq(resolution["pkg@1"].versionString, "1.0.0")
	end)

	suite:case("prereleaseSelectedWhenConstraintOptsIn", function(assert)
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "1.0.0-beta"),
				namedVersion("pkg", "1.0.0-alpha"),
				namedVersion("pkg", "0.9.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", ">=1.0.0-alpha"),
		})
		assert.eq(resolution["pkg@1"].versionString, "1.0.0-beta")
	end)

	suite:case("prereleaseTransitiveDependency", function(assert)
		local universe: solver.Universe = {
			parent = {
				namedVersion("parent", "1.0.0", { pkg = req("pkg", ">=2.0.0-rc.1") }),
			},
			pkg = {
				namedVersion("pkg", "2.0.0-rc.2"),
				namedVersion("pkg", "2.0.0-rc.1"),
				namedVersion("pkg", "1.9.0"),
			},
		}
		local resolution = solver.solve(universe, {
			parent = req("parent", "^1.0.0"),
		})
		assert.eq(resolution["pkg@2"].versionString, "2.0.0-rc.2")
	end)

	suite:case("largeFanoutFindsIntersection", function(assert)
		local universe: solver.Universe = {
			a = { namedVersion("a", "1.0.0", { shared = req("shared", "^1.2.0") }) },
			b = { namedVersion("b", "1.0.0", { shared = req("shared", ">=1.3.0") }) },
			c = { namedVersion("c", "1.0.0", { shared = req("shared", "<1.6.0") }) },
			d = { namedVersion("d", "1.0.0", { shared = req("shared", ">=1.4.0 <1.5.0") }) },
			shared = {
				namedVersion("shared", "1.6.0"),
				namedVersion("shared", "1.5.0"),
				namedVersion("shared", "1.4.0"),
				namedVersion("shared", "1.3.0"),
				namedVersion("shared", "1.2.0"),
			},
		}
		local resolution = solver.solve(universe, {
			a = req("a", "^1.0.0"),
			b = req("b", "^1.0.0"),
			c = req("c", "^1.0.0"),
			d = req("d", "^1.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.4.0")
	end)

	suite:case("largeFanoutMultiMajorCoexists", function(assert)
		-- a requires shared ^1.0.0, b requires shared ^2.0.0
		-- Under multi-major these coexist in different slots
		local universe: solver.Universe = {
			a = { namedVersion("a", "1.0.0", { shared = req("shared", "^1.0.0") }) },
			b = { namedVersion("b", "1.0.0", { shared = req("shared", "^2.0.0") }) },
			shared = {
				namedVersion("shared", "2.5.0"),
				namedVersion("shared", "2.0.0"),
				namedVersion("shared", "1.5.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			a = req("a", "^1.0.0"),
			b = req("b", "^1.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.5.0")
		assert.eq(resolution["shared@2"].versionString, "2.5.0")
	end)

	-- Multi-major specific tests

	suite:case("multiMajorThreeSlots", function(assert)
		local universe: solver.Universe = {
			a = { namedVersion("a", "1.0.0", { shared = req("shared", "^1.0.0") }) },
			b = { namedVersion("b", "1.0.0", { shared = req("shared", "^2.0.0") }) },
			c = { namedVersion("c", "1.0.0", { shared = req("shared", "^3.0.0") }) },
			shared = {
				namedVersion("shared", "3.0.0"),
				namedVersion("shared", "2.0.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			a = req("a", "^1.0.0"),
			b = req("b", "^1.0.0"),
			c = req("c", "^1.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.0.0")
		assert.eq(resolution["shared@2"].versionString, "2.0.0")
		assert.eq(resolution["shared@3"].versionString, "3.0.0")
	end)

	suite:case("zeroMajorSlotsAreFiner", function(assert)
		-- ^0.1.0 and ^0.2.0 land in different slots (0.1 vs 0.2)
		local universe: solver.Universe = {
			a = { namedVersion("a", "1.0.0", { lib = req("lib", "^0.1.0") }) },
			b = { namedVersion("b", "1.0.0", { lib = req("lib", "^0.2.0") }) },
			lib = {
				namedVersion("lib", "0.2.5"),
				namedVersion("lib", "0.1.9"),
			},
		}
		local resolution = solver.solve(universe, {
			a = req("a", "^1.0.0"),
			b = req("b", "^1.0.0"),
		})
		assert.eq(resolution["lib@0.1"].versionString, "0.1.9")
		assert.eq(resolution["lib@0.2"].versionString, "0.2.5")
	end)

	suite:case("sameSlotPicksHighest", function(assert)
		local universe: solver.Universe = {
			shared = {
				namedVersion("shared", "1.5.0"),
				namedVersion("shared", "1.3.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			shared = req("shared", "^1.0.0"),
		})
		assert.eq(resolution["shared@1"].versionString, "1.5.0")
	end)

	suite:case("broadConstraintPicksHighestSlot", function(assert)
		-- >=1.0.0 has no upper bound; should pick highest available (3.0.0) and slot it as @3
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "3.0.0"),
				namedVersion("pkg", "2.0.0"),
				namedVersion("pkg", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", ">=1.0.0"),
		})
		assert.eq(resolution["pkg@3"].versionString, "3.0.0")
	end)

	suite:case("unsatisfiableTransitiveSlotReportsConflict", function(assert)
		-- B depends on A ^2.0.0, but no A@2.x exists in the universe.
		-- The solver should report that A has no satisfying version.
		local universe: solver.Universe = {
			A = {
				namedVersion("A", "1.0.0"),
			},
			B = {
				namedVersion("B", "1.1.0", { A = req("A", "^2.0.0") }),
				namedVersion("B", "1.0.0", { A = req("A", "^2.0.0") }),
			},
		}
		local ok, err = pcall(function()
			solver.solve(universe, {
				A = req("A", "^1.0.0"),
				B = req("B", "^1.0.0"),
			})
		end)
		assert.eq(ok, false)
		local errStr = tostring(err)
		assert.strContains(errStr, "version conflict for 'A'")
	end)

	suite:case("staleConflictNotReportedAfterBacktrack", function(assert)
		-- X@1.1.0 depends on Z ^2.0.0, but no Z@2.x exists.
		-- The solver records a stuck conflict for Z, then backtracks X to 1.0.0.
		-- X@1.0.0 has no deps and succeeds. The stale Z conflict must be cleared
		-- so it doesn't surface as the error. If stuck weren't cleared, this would
		-- erroneously throw "version conflict for 'Z'".
		local universe: solver.Universe = {
			X = {
				namedVersion("X", "1.1.0", { Z = req("Z", "^2.0.0") }),
				namedVersion("X", "1.0.0"),
			},
			Z = {
				namedVersion("Z", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			X = req("X", "^1.0.0"),
		})
		assert.eq(resolution["X@1"].versionString, "1.0.0")
		assert.eq(resolution["Z@2"], nil)
	end)

	suite:case("indirectCircularDependencyShowsFullCycle", function(assert)
		local universe: solver.Universe = {
			a = {
				namedVersion("a", "1.0.0", { b = req("b", "^1.0.0") }),
			},
			b = {
				namedVersion("b", "1.0.0", { c = req("c", "^1.0.0") }),
			},
			c = {
				namedVersion("c", "1.0.0", { a = req("a", "^1.0.0") }),
			},
		}
		assert.throwsWith("circular dependency: a@1 -> b@1 -> c@1 -> a@1", function()
			solver.solve(universe, {
				a = req("a", "^1.0.0"),
			})
		end)
	end)

	suite:case("multiMajorBacktracking", function(assert)
		-- X@1.1.0 needs shared ^2.0.0 AND foo ^1.0.0
		-- foo@1.0.0 needs shared ^2.5.0 (only shared@2.0.0 available, not 2.5.0)
		-- Must backtrack X to 1.0.0 which needs shared ^1.0.0 and no foo
		local universe: solver.Universe = {
			X = {
				namedVersion("X", "1.1.0", {
					shared = req("shared", "^2.0.0"),
					foo = req("foo", "^1.0.0"),
				}),
				namedVersion("X", "1.0.0", { shared = req("shared", "^1.0.0") }),
			},
			foo = {
				namedVersion("foo", "1.0.0", { shared = req("shared", "^2.5.0") }),
			},
			shared = {
				namedVersion("shared", "2.0.0"),
				namedVersion("shared", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			X = req("X", "^1.0.0"),
		})
		assert.eq(resolution["X@1"].versionString, "1.0.0")
		assert.eq(resolution["shared@1"].versionString, "1.0.0")
	end)

	-- Slot routing edge cases

	suite:case("spanningRangePicksHighestSlot", function(assert)
		-- >=1.0.0 <3.0.0 spans majors 1 and 2; should pick highest (2.5.0)
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "2.5.0"),
				namedVersion("pkg", "1.9.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", ">=1.0.0 <3.0.0"),
		})
		assert.eq(resolution["pkg@2"].versionString, "2.5.0")
	end)

	suite:case("upperBoundOnlyPicksHighestSlot", function(assert)
		-- <2.0.0 with no lower bound; should pick highest satisfying
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "2.5.0"),
				namedVersion("pkg", "1.9.0"),
				namedVersion("pkg", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "<2.0.0"),
		})
		assert.eq(resolution["pkg@1"].versionString, "1.9.0")
	end)

	suite:case("tildeConstraintSlotting", function(assert)
		-- ~1.2.0 expands to >=1.2.0 <1.3.0; stays in slot @1
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "1.5.0"),
				namedVersion("pkg", "1.2.5"),
				namedVersion("pkg", "1.2.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "~1.2.0"),
		})
		assert.eq(resolution["pkg@1"].versionString, "1.2.5")
	end)

	suite:case("zeroPatchSlotting", function(assert)
		-- ^0.0.3 expands to =0.0.3; slot is @0.0.3
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "0.0.5"),
				namedVersion("pkg", "0.0.3"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "^0.0.3"),
		})
		assert.eq(resolution["pkg@0.0.3"].versionString, "0.0.3")
	end)

	suite:case("gtWithoutGeqPicksHighestSlot", function(assert)
		-- >1.0.0 with no upper bound; slot is ambiguous, falls through to universe scan
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "3.0.0"),
				namedVersion("pkg", "2.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", ">1.0.0"),
		})
		assert.eq(resolution["pkg@3"].versionString, "3.0.0")
	end)

	suite:case("wildcardPicksHighestSlot", function(assert)
		-- * matches any non-prerelease; slot is ambiguous, resolved from universe
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "4.0.0"),
				namedVersion("pkg", "2.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "*"),
		})
		assert.eq(resolution["pkg@4"].versionString, "4.0.0")
	end)

	suite:case("exactConstraintSlotting", function(assert)
		-- =2.3.1 goes directly to slot @2
		local universe: solver.Universe = {
			pkg = {
				namedVersion("pkg", "3.0.0"),
				namedVersion("pkg", "2.3.1"),
				namedVersion("pkg", "1.0.0"),
			},
		}
		local resolution = solver.solve(universe, {
			pkg = req("pkg", "=2.3.1"),
		})
		assert.eq(resolution["pkg@2"].versionString, "2.3.1")
	end)

	suite:case("multiSlotWithSpanningTransitiveDep", function(assert)
		-- parent needs lib >=1.0.0 <3.0.0 (spans two majors)
		-- Should pick highest satisfying (2.0.0) and slot it correctly
		local universe: solver.Universe = {
			parent = {
				namedVersion("parent", "1.0.0", { lib = req("lib", ">=1.0.0 <3.0.0") }),
			},
			lib = {
				namedVersion("lib", "3.0.0"),
				namedVersion("lib", "2.0.0"),
				namedVersion("lib", "1.5.0"),
			},
		}
		local resolution = solver.solve(universe, {
			parent = req("parent", "^1.0.0"),
		})
		assert.eq(resolution["lib@2"].versionString, "2.0.0")
	end)
end)
