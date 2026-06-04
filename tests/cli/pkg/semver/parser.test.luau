local test = require("@std/test")
local parser = require("@commands/pkg/loom-core/src/semver/parser")

test.suite("semver.parse", function(suite)
	suite:case("basic", function(assert)
		local v = parser.parse("1.2.3")
		assert.eq(v.major, 1)
		assert.eq(v.minor, 2)
		assert.eq(v.patch, 3)
		assert.eq(#v.prerelease, 0)
		assert.eq(#v.build, 0)
	end)

	suite:case("withPrerelease", function(assert)
		local v = parser.parse("1.2.3-alpha.1")
		assert.eq(v.major, 1)
		assert.eq(v.minor, 2)
		assert.eq(v.patch, 3)
		assert.eq(#v.prerelease, 2)
		assert.eq(v.prerelease[1], "alpha")
		assert.eq(v.prerelease[2], 1)
	end)

	suite:case("withBuildMetadata", function(assert)
		local v = parser.parse("1.2.3+build.42")
		assert.eq(v.major, 1)
		assert.eq(v.minor, 2)
		assert.eq(v.patch, 3)
		assert.eq(#v.prerelease, 0)
		assert.eq(#v.build, 2)
		assert.eq(v.build[1], "build")
		assert.eq(v.build[2], "42")
	end)

	suite:case("withPrereleaseAndBuild", function(assert)
		local v = parser.parse("1.2.3-alpha.1+build.42")
		assert.eq(#v.prerelease, 2)
		assert.eq(#v.build, 2)
	end)

	suite:case("hyphenInPrereleaseIdent", function(assert)
		-- spec example: 1.0.0-x-y-z.-- is valid
		local v = parser.parse("1.0.0-x-y-z.--")
		assert.eq(v.prerelease[1], "x-y-z")
		assert.eq(v.prerelease[2], "--")
	end)

	suite:case("numericPrereleaseIdents", function(assert)
		-- spec example: 1.0.0-0.3.7
		local v = parser.parse("1.0.0-0.3.7")
		assert.eq(v.prerelease[1], 0)
		assert.eq(v.prerelease[2], 3)
		assert.eq(v.prerelease[3], 7)
	end)

	suite:case("leadingZeroInMajorIsInvalid", function(assert)
		assert.throwsWith("invalid semver version: '01.0.0' (leading zero in numeric identifier)", function()
			parser.parse("01.0.0")
		end)
	end)

	suite:case("leadingZeroInNumericPrereleaseIsInvalid", function(assert)
		assert.throwsWith("invalid semver pre-release: numeric identifier '01' has a leading zero", function()
			parser.parse("1.0.0-01")
		end)
	end)

	suite:case("emptyPrereleaseIsInvalid", function(assert)
		assert.throwsWith("invalid semver version: '1.0.0-' (expected X.Y.Z)", function()
			parser.parse("1.0.0-")
		end)
	end)

	suite:case("emptyPrereleaseIdentIsInvalid", function(assert)
		assert.throwsWith("invalid semver pre-release: empty identifier in 'alpha..beta'", function()
			parser.parse("1.0.0-alpha..beta")
		end)
	end)

	suite:case("emptyStringIsInvalid", function(assert)
		assert.throwsWith("invalid semver version: '' (expected X.Y.Z)", function()
			parser.parse("")
		end)
	end)

	suite:case("missingPatchIsInvalid", function(assert)
		assert.throwsWith("invalid semver version: '1.0' (expected X.Y.Z)", function()
			parser.parse("1.0")
		end)
	end)

	suite:case("nonNumericComponentsAreInvalid", function(assert)
		assert.throwsWith("invalid semver version: 'a.b.c' (expected X.Y.Z)", function()
			parser.parse("a.b.c")
		end)
	end)

	suite:case("tryParseReturnsNilOnInvalid", function(assert)
		assert.eq(parser.tryParse("not-a-version"), nil)
		assert.eq(parser.tryParse("01.0.0"), nil)
	end)

	suite:case("tryParseReturnsVersionOnValid", function(assert)
		local v = parser.tryParse("1.2.3")
		assert.neq(v, nil)
		assert.eq((v :: parser.Version).major, 1)
	end)
end)

test.suite("semver.compare", function(suite)
	suite:case("numericOrdering", function(assert)
		assert.eq(parser.compare(parser.parse("1.0.0"), parser.parse("2.0.0")), -1)
		assert.eq(parser.compare(parser.parse("2.0.0"), parser.parse("2.1.0")), -1)
		assert.eq(parser.compare(parser.parse("2.1.0"), parser.parse("2.1.1")), -1)
		assert.eq(parser.compare(parser.parse("1.0.0"), parser.parse("1.0.0")), 0)
		assert.eq(parser.compare(parser.parse("2.0.0"), parser.parse("1.0.0")), 1)
	end)

	suite:case("prereleaseLowerThanRelease", function(assert)
		assert.eq(parser.compare(parser.parse("1.0.0-alpha"), parser.parse("1.0.0")), -1)
		assert.eq(parser.compare(parser.parse("1.0.0"), parser.parse("1.0.0-alpha")), 1)
	end)

	suite:case("specCanonicalOrder", function(assert)
		-- From semver spec §11:
		-- 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta
		-- < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
		local versions = {
			parser.parse("1.0.0-alpha"),
			parser.parse("1.0.0-alpha.1"),
			parser.parse("1.0.0-alpha.beta"),
			parser.parse("1.0.0-beta"),
			parser.parse("1.0.0-beta.2"),
			parser.parse("1.0.0-beta.11"),
			parser.parse("1.0.0-rc.1"),
			parser.parse("1.0.0"),
		}

		for i = 1, #versions - 1 do
			assert.eq(parser.compare(versions[i], versions[i + 1]), -1, `expected versions[{i}] < versions[{i + 1}]`)
		end
	end)

	suite:case("buildMetadataIgnored", function(assert)
		assert.eq(parser.compare(parser.parse("1.0.0+build.1"), parser.parse("1.0.0+build.2")), 0)
		assert.eq(parser.compare(parser.parse("1.0.0+a"), parser.parse("1.0.0")), 0)
	end)

	suite:case("numericPrereleaseLowerThanString", function(assert)
		-- numeric id has lower precedence than string id
		assert.eq(parser.compare(parser.parse("1.0.0-1"), parser.parse("1.0.0-alpha")), -1)
	end)

	suite:case("numericPrereleasesComparedByValue", function(assert)
		assert.eq(parser.compare(parser.parse("1.0.0-beta.2"), parser.parse("1.0.0-beta.11")), -1)
	end)

	suite:case("longerPrereleaseHigher", function(assert)
		assert.eq(parser.compare(parser.parse("1.0.0-alpha"), parser.parse("1.0.0-alpha.1")), -1)
	end)
end)

test.suite("semver.sort", function(suite)
	suite:case("ascending", function(assert)
		local versions = parser.sort({
			parser.parse("2.0.0"),
			parser.parse("1.0.0"),
			parser.parse("1.1.0"),
		})
		assert.eq(parser.format(versions[1]), "1.0.0")
		assert.eq(parser.format(versions[2]), "1.1.0")
		assert.eq(parser.format(versions[3]), "2.0.0")
	end)

	suite:case("descending", function(assert)
		local versions = parser.sort({
			parser.parse("1.0.0"),
			parser.parse("2.0.0"),
			parser.parse("1.1.0"),
		}, true)
		assert.eq(parser.format(versions[1]), "2.0.0")
		assert.eq(parser.format(versions[2]), "1.1.0")
		assert.eq(parser.format(versions[3]), "1.0.0")
	end)
end)

test.suite("semver.format", function(suite)
	suite:case("stable", function(assert)
		assert.eq(parser.format(parser.parse("1.2.3")), "1.2.3")
	end)

	suite:case("withPrerelease", function(assert)
		assert.eq(parser.format(parser.parse("1.2.3-alpha.1")), "1.2.3-alpha.1")
	end)

	suite:case("buildMetadataOmitted", function(assert)
		assert.eq(parser.format(parser.parse("1.2.3+build.42")), "1.2.3")
	end)
end)

test.suite("semver.satisfies", function(suite)
	suite:case("wildcard", function(assert)
		local any = parser.parseConstraint("*")
		assert.that(parser.satisfies(parser.parse("0.0.1"), any))
		assert.that(parser.satisfies(parser.parse("99.99.99"), any))
	end)

	suite:case("emptyStringIsInvalid", function(assert)
		assert.throwsWith("invalid constraint: empty string", function()
			parser.parseConstraint("")
		end)
	end)

	suite:case("exact", function(assert)
		local c = parser.parseConstraint("1.2.3")
		assert.that(parser.satisfies(parser.parse("1.2.3"), c))
		assert.eq(parser.satisfies(parser.parse("1.2.4"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.2.2"), c), false)
	end)

	suite:case("exactWithEquals", function(assert)
		local c = parser.parseConstraint("=1.2.3")
		assert.that(parser.satisfies(parser.parse("1.2.3"), c))
		assert.eq(parser.satisfies(parser.parse("1.2.4"), c), false)
	end)

	suite:case("greaterThan", function(assert)
		local c = parser.parseConstraint(">1.2.3")
		assert.eq(parser.satisfies(parser.parse("1.2.3"), c), false)
		assert.that(parser.satisfies(parser.parse("1.2.4"), c))
		assert.that(parser.satisfies(parser.parse("2.0.0"), c))
	end)

	suite:case("greaterThanOrEqual", function(assert)
		local c = parser.parseConstraint(">=1.2.3")
		assert.that(parser.satisfies(parser.parse("1.2.3"), c))
		assert.that(parser.satisfies(parser.parse("1.2.4"), c))
		assert.eq(parser.satisfies(parser.parse("1.2.2"), c), false)
	end)

	suite:case("lessThan", function(assert)
		local c = parser.parseConstraint("<2.0.0")
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
	end)

	suite:case("lessThanOrEqual", function(assert)
		local c = parser.parseConstraint("<=2.0.0")
		assert.that(parser.satisfies(parser.parse("2.0.0"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.1"), c), false)
	end)

	suite:case("caret", function(assert)
		local c = parser.parseConstraint("^1.2.3")
		assert.that(parser.satisfies(parser.parse("1.2.3"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.2.2"), c), false)
	end)

	suite:case("caretZeroMinor", function(assert)
		-- ^0.2.3 -> >=0.2.3 <0.3.0
		local c = parser.parseConstraint("^0.2.3")
		assert.that(parser.satisfies(parser.parse("0.2.3"), c))
		assert.that(parser.satisfies(parser.parse("0.2.9"), c))
		assert.eq(parser.satisfies(parser.parse("0.3.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.0.0"), c), false)
	end)

	suite:case("caretZeroPatch", function(assert)
		-- ^0.0.3 -> =0.0.3 (exact)
		local c = parser.parseConstraint("^0.0.3")
		assert.that(parser.satisfies(parser.parse("0.0.3"), c))
		assert.eq(parser.satisfies(parser.parse("0.0.4"), c), false)
		assert.eq(parser.satisfies(parser.parse("0.0.2"), c), false)
	end)

	suite:case("caretPartialVersion", function(assert)
		-- ^1.2 -> >=1.2.0 <2.0.0
		local c = parser.parseConstraint("^1.2")
		assert.that(parser.satisfies(parser.parse("1.2.0"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
	end)

	suite:case("caretZeroMajorPartial", function(assert)
		-- ^0 (major only zero) -> >=0.0.0 <1.0.0
		local c0 = parser.parseConstraint("^0")
		assert.that(parser.satisfies(parser.parse("0.0.0"), c0))
		assert.that(parser.satisfies(parser.parse("0.9.9"), c0))
		assert.eq(parser.satisfies(parser.parse("1.0.0"), c0), false)

		-- ^0.0 (minor present but zero, no patch) -> >=0.0.0 <0.1.0
		local c00 = parser.parseConstraint("^0.0")
		assert.that(parser.satisfies(parser.parse("0.0.0"), c00))
		assert.that(parser.satisfies(parser.parse("0.0.9"), c00))
		assert.eq(parser.satisfies(parser.parse("0.1.0"), c00), false)
		assert.eq(parser.satisfies(parser.parse("1.0.0"), c00), false)
	end)

	suite:case("tilde", function(assert)
		-- ~1.2.3 -> >=1.2.3 <1.3.0
		local c = parser.parseConstraint("~1.2.3")
		assert.that(parser.satisfies(parser.parse("1.2.3"), c))
		assert.that(parser.satisfies(parser.parse("1.2.9"), c))
		assert.eq(parser.satisfies(parser.parse("1.3.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.2.2"), c), false)
	end)

	suite:case("andRange", function(assert)
		local c = parser.parseConstraint(">=1.0.0 <2.0.0")
		assert.that(parser.satisfies(parser.parse("1.0.0"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("0.9.9"), c), false)
	end)

	suite:case("prereleaseExcludedFromStableConstraint", function(assert)
		-- ^1.0.0 should NOT match 1.0.1-alpha even though 1.0.1-alpha >= 1.0.0
		local c = parser.parseConstraint("^1.0.0")
		assert.eq(parser.satisfies(parser.parse("1.0.1-alpha"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.5.0-rc.1"), c), false)
	end)

	suite:case("prereleaseAllowedWhenExplicitInConstraint", function(assert)
		-- >=1.0.0-alpha explicitly includes pre-release on 1.0.0, so 1.0.0-beta qualifies
		local c = parser.parseConstraint(">=1.0.0-alpha")
		assert.that(parser.satisfies(parser.parse("1.0.0-alpha"), c))
		assert.that(parser.satisfies(parser.parse("1.0.0-beta"), c))
		assert.that(parser.satisfies(parser.parse("1.0.0"), c))
	end)

	suite:case("wildcardExcludesPrerelease", function(assert)
		-- * matches only stable releases, not pre-releases (npm semver behavior)
		assert.eq(parser.satisfies(parser.parse("1.0.0-alpha"), parser.parseConstraint("*")), false)
		assert.that(parser.satisfies(parser.parse("1.0.0"), parser.parseConstraint("*")))
	end)

	suite:case("prereleaseExcludedAtLtBoundary", function(assert)
		-- <1.0.0 has no pre-release tag, so 1.0.0-beta is excluded despite being numerically less
		local c = parser.parseConstraint("<1.0.0")
		assert.eq(parser.satisfies(parser.parse("1.0.0-beta"), c), false)
		assert.that(parser.satisfies(parser.parse("0.9.9"), c))
	end)

	suite:case("prereleaseOnDifferentTupleExcluded", function(assert)
		-- >=2.1.0-alpha2 allows pre-releases on 2.1.0 but NOT on other M.m.p tuples
		local c = parser.parseConstraint(">=2.1.0-alpha2")
		assert.that(parser.satisfies(parser.parse("2.1.0-alpha2"), c))
		assert.that(parser.satisfies(parser.parse("2.1.0-beta"), c))
		assert.that(parser.satisfies(parser.parse("2.1.0"), c))
		assert.that(parser.satisfies(parser.parse("3.0.0"), c))
		assert.eq(parser.satisfies(parser.parse("3.0.0-alpha2"), c), false)
		assert.eq(parser.satisfies(parser.parse("2.1.0-alpha1"), c), false)
	end)

	suite:case("prereleaseWithLeConstraint", function(assert)
		-- <=2.1.0-alpha2 allows earlier pre-releases on 2.1.0 and lower stable releases,
		-- but NOT the stable 2.1.0 (release > any pre-release of same M.m.p),
		-- and NOT pre-releases on a different M.m.p tuple
		local c = parser.parseConstraint("<=2.1.0-alpha2")
		assert.that(parser.satisfies(parser.parse("2.1.0-alpha2"), c))
		assert.that(parser.satisfies(parser.parse("2.1.0-alpha1"), c))
		assert.that(parser.satisfies(parser.parse("2.0.0"), c))
		assert.eq(parser.satisfies(parser.parse("2.1.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.0.0-alpha2"), c), false)
	end)

	suite:case("caretMajorOnly", function(assert)
		-- ^1 -> >=1.0.0 <2.0.0
		local c = parser.parseConstraint("^1")
		assert.that(parser.satisfies(parser.parse("1.0.0"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("0.9.9"), c), false)
	end)

	suite:case("caretMajorMinorOnly", function(assert)
		-- ^1.1 -> >=1.1.0 <2.0.0
		local c = parser.parseConstraint("^1.1")
		assert.that(parser.satisfies(parser.parse("1.1.0"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("1.0.9"), c), false)
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
	end)

	suite:case("partialWildcardMajorStar", function(assert)
		-- 1.* / 1.x / 1.X -> >=1.0.0 <2.0.0
		for _, pattern in { "1.*", "1.x", "1.X" } do
			local c = parser.parseConstraint(pattern)
			assert.that(parser.satisfies(parser.parse("1.0.0"), c), `{pattern} should match 1.0.0`)
			assert.that(parser.satisfies(parser.parse("1.9.9"), c), `{pattern} should match 1.9.9`)
			assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false, `{pattern} should not match 2.0.0`)
			assert.eq(parser.satisfies(parser.parse("0.9.9"), c), false, `{pattern} should not match 0.9.9`)
		end
	end)

	suite:case("partialWildcardPatchStar", function(assert)
		-- 1.2.* / 1.2.x / 1.2.X -> >=1.2.0 <1.3.0
		for _, pattern in { "1.2.*", "1.2.x", "1.2.X" } do
			local c = parser.parseConstraint(pattern)
			assert.that(parser.satisfies(parser.parse("1.2.0"), c), `{pattern} should match 1.2.0`)
			assert.that(parser.satisfies(parser.parse("1.2.9"), c), `{pattern} should match 1.2.9`)
			assert.eq(parser.satisfies(parser.parse("1.3.0"), c), false, `{pattern} should not match 1.3.0`)
			assert.eq(parser.satisfies(parser.parse("1.1.9"), c), false, `{pattern} should not match 1.1.9`)
		end
	end)

	suite:case("tildeMajorOnly", function(assert)
		-- ~1 -> >=1.0.0 <2.0.0
		local c = parser.parseConstraint("~1")
		assert.that(parser.satisfies(parser.parse("1.0.0"), c))
		assert.that(parser.satisfies(parser.parse("1.9.9"), c))
		assert.eq(parser.satisfies(parser.parse("2.0.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("0.9.9"), c), false)
	end)

	suite:case("tildeMajorMinorOnly", function(assert)
		-- ~1.2 -> >=1.2.0 <1.3.0
		local c = parser.parseConstraint("~1.2")
		assert.that(parser.satisfies(parser.parse("1.2.0"), c))
		assert.that(parser.satisfies(parser.parse("1.2.9"), c))
		assert.eq(parser.satisfies(parser.parse("1.3.0"), c), false)
		assert.eq(parser.satisfies(parser.parse("1.1.9"), c), false)
	end)
end)

test.suite("semver.formatConstraint", function(suite)
	suite:case("wildcard", function(assert)
		assert.eq(parser.formatConstraint({}), "*")
	end)

	suite:case("roundTrip", function(assert)
		local c = parser.parseConstraint(">=1.0.0 <2.0.0")
		local formatted = parser.formatConstraint(c)
		assert.that(formatted:find(">=1.0.0") ~= nil)
		assert.that(formatted:find("<2.0.0") ~= nil)
	end)
end)
