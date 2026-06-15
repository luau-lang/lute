--!strict

local tableext = require("@std/tableext")

local parser = require("./parser")

export type PackageVersion = {
	read name: string,
	read version: parser.Version,
	read versionString: string,
	read dependencies: { [string]: Requirement },
}

export type Requirement = {
	read name: string,
	read constraint: parser.Constraint,
	read requiredBy: string?,
}

-- All known versions per package name, sorted newest-first.
export type Universe = { [string]: { PackageVersion } }

-- One selected PackageVersion per compatibility slot.
-- Slot keys: "name@major" (major>0), "name@0.minor" (0.Y), "name@0.0.patch" (0.0.Z)
export type Resolution = { [string]: PackageVersion }

-- Constraints accumulated during the search, keyed by slot.
type ConstraintSet = { [string]: { [string]: Requirement } }

local function computeSlot(name: string, version: parser.Version): string
	if version.major > 0 then
		return `{name}@{version.major}`
	elseif version.minor > 0 then
		return `{name}@0.{version.minor}`
	else
		return `{name}@0.0.{version.patch}`
	end
end

local function slotFromConstraint(name: string, constraint: parser.Constraint): string?
	if #constraint == 0 then
		return nil
	end

	if #constraint == 1 and constraint[1].op == "=" then
		return computeSlot(name, constraint[1].version)
	end

	local lower: parser.Version? = nil
	local upper: parser.Version? = nil
	for _, comp in constraint do
		if (comp.op == ">=" or comp.op == ">") and lower == nil then
			lower = comp.version
		elseif comp.op == "<" and upper == nil then
			upper = comp.version
		end
	end

	-- split nil checks for better type inference.
	if lower == nil then
		return nil
	end
	if upper == nil then
		return nil
	end

	if lower.major > 0 and upper.major <= lower.major + 1 then
		return `{name}@{lower.major}`
	elseif lower.major == 0 and lower.minor > 0 and upper.major == 0 and upper.minor <= lower.minor + 1 then
		return `{name}@0.{lower.minor}`
	elseif lower.major == 0 and lower.minor == 0 and upper.major == 0 and upper.minor == 0 then
		return `{name}@0.0.{lower.patch}`
	end

	return nil
end

local function nameFromSlot(slotKey: string): string
	local name = slotKey:match("^(.+)@")
	return name or slotKey
end

local function resolveSlotKey(name: string, constraint: parser.Constraint, universe: Universe): string
	local slot = slotFromConstraint(name, constraint)
	if slot then
		return slot
	end

	local candidates = universe[name]
	if candidates then
		for _, c in candidates do
			if parser.satisfies(c.version, constraint) then
				return computeSlot(name, c.version)
			end
		end
	end

	return `{name}@0`
end

local function formatConflict(name: string, requirements: { Requirement }): string
	local body: { string } = {}
	for _, req in requirements do
		local source = req.requiredBy or "root"
		table.insert(body, `  {parser.formatConstraint(req.constraint)}  (required by {source})`)
	end
	table.sort(body)

	return `version conflict for '{name}': no available version satisfies:\n` .. table.concat(body, "\n")
end

local function constraintsFor(set: ConstraintSet, slotKey: string): { Requirement }
	local list: { Requirement } = {}
	for _, req in set[slotKey] or {} do
		table.insert(list, req)
	end
	return list
end

-- Pick the slot with the fewest satisfying candidates (MRV heuristic).
-- Tie-break alphabetically for determinism.
-- Returns nil when all constrained slots are already selected.
local function pickPending(set: ConstraintSet, selected: Resolution, universe: Universe): string?
	local best: string? = nil
	local bestCount: number = math.huge

	for slotKey in set do
		if selected[slotKey] ~= nil then
			continue
		end

		local name = nameFromSlot(slotKey)
		local candidates = universe[name]
		if candidates == nil then
			return slotKey
		end

		local reqs = constraintsFor(set, slotKey)
		local count = 0
		for _, candidate in candidates do
			local satisfiesAll = tableext.all(reqs, function(req)
				return parser.satisfies(candidate.version, req.constraint)
			end)
			if satisfiesAll then
				count += 1
			end
		end

		if count == 0 then
			return slotKey
		end

		-- fewest candiates with alphabetical tie-breaker
		if best == nil or count < bestCount or (count == bestCount and slotKey < best) then
			best = slotKey
			bestCount = count
		end
	end

	return best
end

-- Merge `deps` into the constraint set under sourceKey.
-- TODO check the constraints against already-selected versions (forward checking).
local function propagateDeps(
	set: ConstraintSet,
	sourceKey: string,
	deps: { [string]: Requirement },
	universe: Universe
): ConstraintSet
	local out: ConstraintSet = table.clone(set)

	for alias, dep in deps do
		local slotKey = resolveSlotKey(dep.name, dep.constraint, universe)

		local existing = out[slotKey]
		local merged: { [string]: Requirement } = if existing then table.clone(existing) else {}
		merged[`{sourceKey}:{alias}`] = table.freeze({
			name = dep.name,
			constraint = dep.constraint,
			requiredBy = sourceKey,
		})
		out[slotKey] = merged
	end

	return out
end

local function checkAcyclic(selected: Resolution, universe: Universe)
	local path: { string } = {}
	local onPath: { [string]: number } = {}
	local done: { [string]: boolean } = {}

	local function visit(slotKey: string)
		if done[slotKey] then
			return
		end
		if onPath[slotKey] then
			local cycleStart = onPath[slotKey]
			local cycle: { string } = {}
			for i = cycleStart, #path do
				table.insert(cycle, path[i])
			end
			table.insert(cycle, slotKey)
			error(`circular dependency: {table.concat(cycle, " -> ")}`)
		end

		table.insert(path, slotKey)
		onPath[slotKey] = #path

		local pkg = selected[slotKey]
		if pkg then
			for _, dep in pkg.dependencies do
				local depSlot = resolveSlotKey(dep.name, dep.constraint, universe)
				if selected[depSlot] then
					visit(depSlot)
				end
			end
		end

		onPath[slotKey] = nil
		table.remove(path)
		done[slotKey] = true
	end

	for slotKey in selected do
		visit(slotKey)
	end
end

type DecisionFrame = {
	read slotKey: string,
	read candidates: { PackageVersion },
	candidateIdx: number,
	read prevConstraints: ConstraintSet,
	read prevSelected: Resolution,
}

local function solve(universe: Universe, roots: { [string]: Requirement }): Resolution
	-- Seed the constraint set from root requirements, keyed by slot.
	local initial: ConstraintSet = {}
	for alias, req in roots do
		local slotKey = resolveSlotKey(req.name, req.constraint, universe)
		initial[slotKey] = initial[slotKey] or {}
		initial[slotKey][`root:{alias}`] = table.freeze({
			name = req.name,
			constraint = req.constraint,
			requiredBy = req.requiredBy,
		})
	end

	local stuck: { name: string, requirements: { Requirement }, depth: number }? = nil

	local stack: { DecisionFrame } = {}
	local constraints = initial
	local selected: Resolution = {}

	while true do
		local slotKey = pickPending(constraints, selected, universe)

		if slotKey == nil then
			checkAcyclic(selected, universe)
			return table.freeze(selected)
		end

		local name = nameFromSlot(slotKey)

		if universe[name] == nil then
			error(`unknown package '{name}': not found in universe`)
		end

		local reqs = constraintsFor(constraints, slotKey)

		-- Filter candidates to those satisfying all current constraints.
		local candidates: { PackageVersion } = {}
		for _, candidate in universe[name] do
			local satisfiesAll = tableext.all(reqs, function(r)
				return parser.satisfies(candidate.version, r.constraint)
			end)
			if satisfiesAll then
				table.insert(candidates, candidate)
			end
		end

		-- Advance with the first candidate (universe is sorted newest-first).
		if #candidates > 0 then
			local candidate = candidates[1]
			local sourceKey = `{candidate.name}@{candidate.versionString}`
			local nextSelected = table.clone(selected)
			nextSelected[slotKey] = candidate
			local nextConstraints = propagateDeps(constraints, sourceKey, candidate.dependencies, universe)

			table.insert(stack, {
				slotKey = slotKey,
				candidates = candidates,
				candidateIdx = 1,
				prevConstraints = constraints,
				prevSelected = selected,
			})
			constraints = nextConstraints
			selected = nextSelected
		else
			local depth = #stack
			if stuck == nil or depth < stuck.depth then
				stuck = { name = name, requirements = reqs, depth = depth }
			end

			-- Backtrack: try next candidates at earlier decision levels.
			local backtracked = false
			while #stack > 0 do
				local frame = stack[#stack]

				if frame.candidateIdx < #frame.candidates then
					local idx = frame.candidateIdx + 1
					local candidate = frame.candidates[idx]
					local sourceKey = `{candidate.name}@{candidate.versionString}`
					local nextSelected = table.clone(frame.prevSelected)
					nextSelected[frame.slotKey] = candidate
					local nextConstraints =
						propagateDeps(frame.prevConstraints, sourceKey, candidate.dependencies, universe)

					frame.candidateIdx = idx
					constraints = nextConstraints
					selected = nextSelected
					backtracked = true
					if stuck and stuck.depth > #stack then
						stuck = nil
					end
					break
				end

				table.remove(stack)
			end

			if not backtracked then
				if stuck then
					error(formatConflict(stuck.name, stuck.requirements))
				end
				error("dependency resolution failed")
			end
		end
	end
end

return {
	solve = solve,
}
