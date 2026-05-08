--!strict

export type PrereleaseId = string | number

export type Version = {
	read major: number,
	read minor: number,
	read patch: number,
	read prerelease: { PrereleaseId },
	read build: { string },
}

export type Comparator = {
	read op: "=" | ">" | ">=" | "<" | "<=",
	read version: Version,
}

-- A constraint is a list of Comparators joined by AND.
-- An empty list means "any version" (wildcard).
export type Constraint = { Comparator }

-- Matches only [0-9A-Za-z-]
local function isValidIdentChar(c: string): boolean
	return c:match("^[0-9A-Za-z%-]$") ~= nil
end

local function isAllDigits(s: string): boolean
	return s:match("^[0-9]+$") ~= nil
end

local function hasLeadingZero(s: string): boolean
	return #s > 1 and s:sub(1, 1) == "0"
end

local function parseIdents(raw: string, label: string): { string }
	-- Detect empty identifiers from leading/trailing dots or consecutive dots
	if raw:sub(1, 1) == "." or raw:sub(-1) == "." or raw:find("%.%.") then
		error(`invalid semver {label}: empty identifier in '{raw}'`)
	end

	local idents: { string } = {}
	for ident in raw:gmatch("[^%.]+") do
		for i = 1, #ident do
			if not isValidIdentChar(ident:sub(i, i)) then
				error(`invalid semver {label}: identifier '{ident}' contains invalid character`)
			end
		end
		table.insert(idents, ident)
	end

	if #idents == 0 then
		error(`invalid semver {label}: '{raw}' produced no identifiers`)
	end

	return idents
end

local function parsePrereleaseIdents(raw: string): { PrereleaseId }
	local rawIdents = parseIdents(raw, "pre-release")
	local result: { PrereleaseId } = {}

	for _, ident in rawIdents do
		if not isAllDigits(ident) then
			table.insert(result, ident)
			continue
		end

		if hasLeadingZero(ident) then
			error(`invalid semver pre-release: numeric identifier '{ident}' has a leading zero`)
		end

		table.insert(result, tonumber(ident) :: number)
	end

	return result
end

local function parseVersionString(s: string): Version
	-- Split off build metadata first (after +)
	local versionPartOptional, buildRaw = s:match("^([^+]+)%+(.+)$")
	if versionPartOptional == nil then
		buildRaw = nil
	end

	local versionPart = versionPartOptional or s

	-- Split off pre-release (after -)
	local corePartOptional, prereleaseRaw = versionPart:match("^([^%-]+)%-(.+)$")
	if corePartOptional == nil then
		prereleaseRaw = nil
	end

	local corePart = corePartOptional or versionPart

	-- Parse M.m.p
	local majorStr, minorStr, patchStr = corePart:match("^(%d+)%.(%d+)%.(%d+)$")
	if majorStr == nil then
		error(`invalid semver version: '{s}' (expected X.Y.Z)`)
	end

	for _, part in { majorStr, minorStr, patchStr } do
		assert(part) -- FIXME(Luau): type inference doesn't understand the loop invariant that these are all non-nil

		if hasLeadingZero(part) then
			error(`invalid semver version: '{s}' (leading zero in numeric identifier)`)
		end
	end

	local prerelease: { PrereleaseId } = {}
	if prereleaseRaw ~= nil then
		-- Check that pre-release section is not just an empty trailing hyphen
		if prereleaseRaw == "" then
			error(`invalid semver version: '{s}' (empty pre-release)`)
		end

		prerelease = parsePrereleaseIdents(prereleaseRaw)
	end

	local build: { string } = {}
	if buildRaw ~= nil then
		if buildRaw == "" then
			error(`invalid semver version: '{s}' (empty build metadata)`)
		end

		build = parseIdents(buildRaw, "build metadata")
	end

	return table.freeze({
		major = tonumber(majorStr) :: number,
		minor = tonumber(minorStr) :: number,
		patch = tonumber(patchStr) :: number,
		prerelease = table.freeze(prerelease),
		build = table.freeze(build),
	})
end

local function parse(s: string): Version
	return parseVersionString(s)
end

local function tryParse(s: string): Version?
	local ok, result = pcall(parseVersionString, s)

	if not ok then
		return nil
	end

	return result
end

-- Compare two versions per semver spec §11.
-- Returns -1 if a < b, 0 if a == b, 1 if a > b.
-- Build metadata is ignored.
local function compare(a: Version, b: Version): number
	if a.major ~= b.major then
		return if a.major < b.major then -1 else 1
	end

	if a.minor ~= b.minor then
		return if a.minor < b.minor then -1 else 1
	end

	if a.patch ~= b.patch then
		return if a.patch < b.patch then -1 else 1
	end

	-- Equal M.m.p — compare pre-release
	local aHasPre = #a.prerelease > 0
	local bHasPre = #b.prerelease > 0

	if not aHasPre and not bHasPre then
		return 0
	end

	-- Pre-release < release
	if aHasPre and not bHasPre then
		return -1
	end

	if not aHasPre and bHasPre then
		return 1
	end

	-- Both have pre-release — compare identifier by identifier
	local aIds = a.prerelease
	local bIds = b.prerelease
	local minLen = math.min(#aIds, #bIds)

	for i = 1, minLen do
		local ai = aIds[i]
		local bi = bIds[i]

		if ai == bi then
			continue
		end

		if typeof(ai) == "number" and typeof(bi) == "number" then
			return if ai < bi then -1 else 1
		end

		-- Numeric < non-numeric
		if typeof(ai) == "number" and typeof(bi) ~= "number" then
			return -1
		end

		if typeof(ai) ~= "number" and typeof(bi) == "number" then
			return 1
		end

		assert(typeof(ai) == "string" and typeof(bi) == "string")

		-- Both strings: ASCII lexicographic
		return if ai < bi then -1 else 1
	end

	-- All compared identifiers are equal — larger set has higher precedence
	if #aIds ~= #bIds then
		return if #aIds < #bIds then -1 else 1
	end

	return 0
end

local function sort(versions: { Version }, descending: boolean?): { Version }
	local copy = table.clone(versions)

	table.sort(copy, function(a, b)
		local c = compare(a, b)
		return if descending then c > 0 else c < 0
	end)

	return copy
end

-- Build metadata (§10) is intentionally omitted: it does not affect precedence
-- and carries no meaning for package resolution.
local function format(v: Version): string
	local base = `{v.major}.{v.minor}.{v.patch}`

	if #v.prerelease == 0 then
		return base
	end

	local parts: { string } = {}
	for _, id in v.prerelease do
		table.insert(parts, tostring(id))
	end

	return `{base}-{table.concat(parts, ".")}`
end

-- Parse a partial version string "X", "X.Y", or "X.Y.Z" into (major, minor?, patch?)
-- Used for caret/tilde with partial versions.
local function parsePartialVersion(s: string): (number, number?, number?)
	local major, minor, patch = s:match("^(%d+)%.(%d+)%.(%d+)$")
	if major then
		return tonumber(major) :: number, tonumber(minor), tonumber(patch)
	end

	local ma, mi = s:match("^(%d+)%.(%d+)$")
	if ma then
		return tonumber(ma) :: number, tonumber(mi), nil
	end

	local ma2 = s:match("^(%d+)$")
	if ma2 then
		return tonumber(ma2) :: number, nil, nil
	end

	error(`invalid partial version: '{s}'`)
end

local function makeVersion(major: number, minor: number?, patch: number?): Version
	return table.freeze({
		major = major,
		minor = minor or 0,
		patch = patch or 0,
		prerelease = table.freeze({} :: { PrereleaseId }),
		build = table.freeze({} :: { string }),
	})
end

-- Build a Comparator table.
local function makeComparator(op: "=" | ">" | ">=" | "<" | "<=", v: Version): Comparator
	return table.freeze({ op = op, version = v })
end

-- Expand caret constraint per npm semver semantics.
local function expandCaret(s: string): Constraint
	local major, minor, patch = parsePartialVersion(s)

	if major > 0 then
		-- ^X.Y.Z -> >=X.Y.Z <X+1.0.0
		local lo = makeVersion(major, minor or 0, patch or 0)
		local hi = makeVersion(major + 1, 0, 0)
		return table.freeze({ makeComparator(">=", lo), makeComparator("<", hi) })
	end

	if minor ~= nil and minor > 0 then
		-- ^0.Y.Z -> >=0.Y.Z <0.Y+1.0
		local lo = makeVersion(0, minor, patch or 0)
		local hi = makeVersion(0, minor + 1, 0)
		return table.freeze({ makeComparator(">=", lo), makeComparator("<", hi) })
	end

	if patch ~= nil then
		-- ^0.0.Z -> =0.0.Z
		local exact = makeVersion(0, 0, patch)
		return table.freeze({ makeComparator("=", exact) })
	end

	if minor ~= nil then
		-- ^0.0 (minor present but zero, no patch) -> >=0.0.0 <0.1.0
		local lo = makeVersion(0, 0, 0)
		local hi = makeVersion(0, 1, 0)
		return table.freeze({ makeComparator(">=", lo), makeComparator("<", hi) })
	end

	-- ^0 (major only, zero) -> >=0.0.0 <1.0.0
	local lo = makeVersion(0, 0, 0)
	local hi = makeVersion(1, 0, 0)
	return table.freeze({ makeComparator(">=", lo), makeComparator("<", hi) })
end

-- Expand tilde constraint: ~X.Y.Z -> >=X.Y.Z <X.Y+1.0
local function expandTilde(s: string): Constraint
	local major, minor, patch = parsePartialVersion(s)

	local lo = makeVersion(major, minor or 0, patch or 0)
	local hi = if minor then makeVersion(major, minor + 1, 0) else makeVersion(major + 1, 0, 0)

	return table.freeze({ makeComparator(">=", lo), makeComparator("<", hi) })
end

-- Parse a single comparator token like ">=1.2.3", "1.2.3", or "=1.2.3".
-- Note: Lua patterns do not support alternation (|), so operators are checked manually.
local function parseSingleComparator(token: string): Comparator
	if token:sub(1, 2) == ">=" then
		return makeComparator(">=", parse(token:sub(3)))
	end

	if token:sub(1, 2) == "<=" then
		return makeComparator("<=", parse(token:sub(3)))
	end

	if token:sub(1, 1) == ">" then
		return makeComparator(">", parse(token:sub(2)))
	end

	if token:sub(1, 1) == "<" then
		return makeComparator("<", parse(token:sub(2)))
	end

	if token:sub(1, 1) == "=" then
		return makeComparator("=", parse(token:sub(2)))
	end

	return makeComparator("=", parse(token))
end

local function parseConstraint(s: string): Constraint
	local trimmed = s:match("^%s*(.-)%s*$") :: string

	if trimmed == "" then
		error(`invalid constraint: empty string`)
	end

	if trimmed == "*" then
		return table.freeze({} :: Constraint)
	end

	if trimmed:sub(1, 1) == "^" then
		return expandCaret(trimmed:sub(2))
	end

	if trimmed:sub(1, 1) == "~" then
		return expandTilde(trimmed:sub(2))
	end

	-- Space-separated comparators (AND)
	local comparators: Constraint = {}
	for token in trimmed:gmatch("%S+") do
		table.insert(comparators, parseSingleComparator(token))
	end

	if #comparators == 0 then
		error(`invalid constraint: '{s}'`)
	end

	return table.freeze(comparators)
end

-- Check if a version satisfies a single comparator.
local function satisfiesComparator(v: Version, c: Comparator): boolean
	local cmp = compare(v, c.version)

	if c.op == "=" then
		return cmp == 0
	end

	if c.op == ">" then
		return cmp > 0
	end

	if c.op == ">=" then
		return cmp >= 0
	end

	if c.op == "<" then
		return cmp < 0
	end

	if c.op == "<=" then
		return cmp <= 0
	end

	return false
end

local function prereleaseExcluded(v: Version, comparators: Constraint): boolean
	if #v.prerelease == 0 then
		return false
	end

	-- Allowed only if a comparator explicitly names a pre-release on the same M.m.p tuple.
	for _, c in comparators do
		if #c.version.prerelease > 0
			and c.version.major == v.major
			and c.version.minor == v.minor
			and c.version.patch == v.patch
		then
			return false
		end
	end
	return true
end

local function satisfies(v: Version, constraint: Constraint): boolean
	-- Wildcard (*): no comparator names a pre-release, so pre-releases are excluded.
	if #constraint == 0 then
		return #v.prerelease == 0
	end

	-- Exclude pre-release versions unless the constraint explicitly opts in
	if prereleaseExcluded(v, constraint) then
		return false
	end

	for _, c in constraint do
		if not satisfiesComparator(v, c) then
			return false
		end
	end

	return true
end

local function formatConstraint(constraint: Constraint): string
	if #constraint == 0 then
		return "*"
	end

	local parts: { string } = {}
	for _, c in constraint do
		-- Omit the "=" prefix for exact comparators; bare version is conventional.
		local token = if c.op == "=" then format(c.version) else `{c.op}{format(c.version)}`
		table.insert(parts, token)
	end

	return table.concat(parts, " ")
end

return {
	parse = parse,
	tryParse = tryParse,
	parseConstraint = parseConstraint,
	satisfies = satisfies,
	compare = compare,
	sort = sort,
	format = format,
	formatConstraint = formatConstraint,
}
