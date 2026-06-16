--!strict

local tableext = require("@std/tableext")
local deque = require("@batteries/collections/deque")

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
	read aliasedAs: string?,
}

-- All known versions per package name, sorted newest-first.
export type Universe = { [string]: { PackageVersion } }

-- One selected PackageVersion per package name.
export type Resolution = { [string]: PackageVersion }

-- Find the highest-precedence version in `versions` satisfying all requirements.
-- `versions` must already be sorted newest-first.
local function findBest(versions: { PackageVersion }?, requirements: { Requirement }): PackageVersion?
	if versions == nil then
		return nil
	end

	for _, pv in versions do
		if tableext.all(requirements, function(req)
			return parser.satisfies(pv.version, req.constraint)
		end) then
			return pv
		end
	end
	return nil
end

local function formatConflict(name: string, requirements: { Requirement }): string
	local lines: { string } = { `version conflict for '{name}': no available version satisfies:` }

	for _, req in requirements do
		local source = req.requiredBy or "root"
		if req.aliasedAs then
			table.insert(lines, `  {parser.formatConstraint(req.constraint)}  (required by {source} as {req.aliasedAs})`)
		else
			table.insert(lines, `  {parser.formatConstraint(req.constraint)}  (required by {source})`)
		end
	end

	return table.concat(lines, "\n")
end

local function solve(universe: Universe, roots: { [string]: Requirement }): Resolution
	-- constraintsBySource[targetPkg][sourceKey] = Requirement.
	-- Keyed by source lets us retract constraints when a selection changes.
	-- Source keys: "root:<alias>" for root requirements, "<pkg>@<version>" for transitive deps.
	local constraintsBySource: { [string]: { [string]: Requirement } } = {}

	local selected: Resolution = {}

	-- Set-based FIFO queue: each package name appears at most once at a time.
	local queue = deque.new<<string>>()
	local inQueue: { [string]: boolean } = {}

	local function enqueue(name: string)
		if inQueue[name] then
			return
		end

		inQueue[name] = true
		queue:pushback(name)
	end

	local function dequeue(): string
		local name = queue:popfront()
		inQueue[name] = nil
		return name
	end

	local function addConstraint(targetName: string, sourceKey: string, req: Requirement)
		constraintsBySource[targetName] = constraintsBySource[targetName] or {}
		constraintsBySource[targetName][sourceKey] = req
		enqueue(targetName)
	end

	local function removeConstraintsFrom(sourceKey: string, deps: { [string]: Requirement })
		for alias, dep in deps do
			local targets = constraintsBySource[dep.name]
			local key = `{sourceKey}:{alias}`

			if not targets or targets[key] == nil then
				continue
			end

			targets[key] = nil
			enqueue(dep.name)
		end
	end

	local function getConstraintList(name: string): { Requirement }
		local list: { Requirement } = {}

		for _, req in constraintsBySource[name] or {} do
			table.insert(list, req)
		end

		return list
	end

	-- Process root requirements in sorted alias order for deterministic resolution.
	local rootAliases: { string } = {}

	for alias, _ in roots do
		table.insert(rootAliases, alias)
	end

	table.sort(rootAliases)

	for _, alias in rootAliases do
		local req = roots[alias]
		addConstraint(
			req.name,
			`root:{alias}`,
			table.freeze({
				name = req.name,
				constraint = req.constraint,
				requiredBy = req.requiredBy,
				aliasedAs = req.aliasedAs,
			})
		)
	end

	-- Tracks which versions have ever been selected per package.
	-- Re-selecting a version that was already unselected signals a circular dependency.
	local everSelected: { [string]: { [string]: boolean } } = {}

	while #queue > 0 do
		local name = dequeue()

		local constraints = getConstraintList(name)

		if #constraints == 0 then
			-- All constraints retracted: deselect and propagate retraction to dependents.
			local old = selected[name]
			if old then
				selected[name] = nil
				removeConstraintsFrom(`{old.name}@{old.versionString}`, old.dependencies)
			end
			continue
		end

		if universe[name] == nil then
			error(`unknown package '{name}': not found in universe`)
		end

		local best = findBest(universe[name], constraints)

		if best == nil then
			-- A pending item may retract a constraint once evaluated, making this
			-- conflict spurious. Defer until the queue is settled.
			if #queue > 0 then
				enqueue(name)
				continue
			end

			error(formatConflict(name, constraints))
		end

		-- Two PackageVersion objects with equal versions (differing only in build metadata)
		-- are treated as the same selection.
		local alreadySelected = selected[name] ~= nil and parser.compare(selected[name].version, best.version) == 0
		if alreadySelected then
			continue
		end

		-- Re-selecting a previously unselected version means circular dependency.
		if not everSelected[name] then
			everSelected[name] = {}
		end

		if everSelected[name][best.versionString] then
			error(`circular dependency detected for package '{name}'`)
		end
		everSelected[name][best.versionString] = true

		local old = selected[name]
		selected[name] = best

		-- Retract constraints contributed by the old selection.
		if old then
			removeConstraintsFrom(`{old.name}@{old.versionString}`, old.dependencies)
		end

		-- Publish constraints from the new selection.
		local newKey = `{best.name}@{best.versionString}`
		for alias, dep in best.dependencies do
			addConstraint(
				dep.name,
				`{newKey}:{alias}`,
				table.freeze({
					name = dep.name,
					constraint = dep.constraint,
					requiredBy = newKey,
					aliasedAs = if alias ~= dep.name then alias else nil,
				})
			)
		end
	end

	local visiting: { [string]: boolean } = {}
	local done: { [string]: boolean } = {}

	local function checkCycles(name: string)
		if done[name] then
			return
		end

		if visiting[name] then
			error(`circular dependency detected for package '{name}'`)
		end

		visiting[name] = true

		local pkg = selected[name]
		if pkg then
			for _, dep in pkg.dependencies do
				if selected[dep.name] then
					checkCycles(dep.name)
				end
			end
		end

		visiting[name] = false
		done[name] = true
	end

	for name in selected do
		checkCycles(name)
	end

	return table.freeze(selected)
end

return {
	solve = solve,
}
