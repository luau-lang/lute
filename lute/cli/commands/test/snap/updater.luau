local fs = require("@std/fs")
local snapty = require("./types")
local io = require("@std/io")
local path = require("@std/path")
local sty = require("./styles")
local ps = require("@std/process")
local strext = require("@std/stringext")

-- Write content directly to a .snap artifact file.
-- Used both for creating new snapshots and updating existing ones.
local function writeSnapshot(snappath: string, content: string): boolean
	local ok = pcall(fs.writestringtofile, snappath, content)
	return ok
end

local function acceptAll(result: snapty.snapresult)
	-- Auto-accept all new snapshots and failures
	local accepted = 0
	for _, n in result.new do
		local ok = writeSnapshot(n.artifactpath, n.actual)
		if ok then
			accepted += 1
		else
			print(`Failed to create {n.artifactpath}`)
		end
	end
	for _, f in result.failed do
		local ok = writeSnapshot(f.artifactpath, f.actual)
		if ok then
			accepted += 1
		else
			print(`Failed to update {f.artifactpath}`)
		end
	end
	print(`\nUpdated {accepted} snapshot(s).`)
end

local function acceptInteractive(failures: { snapty.snapfail }, news: { snapty.snapnew }): number
	local function prompt(acceptAll: boolean): string
		if acceptAll then
			return "a"
		end
		local prompt = sty.dim("[a]ccept  [r]eject  [A]ccept all  > ")
		local choice = io.input(prompt)
		return strext.trim(choice)
	end

	local function updateArtifact(choice, artifactpath, content): boolean
		local created = false
		if choice == "a" then
			created = writeSnapshot(artifactpath, content)
			if created then
				print(sty.pass("\tCreated ") .. sty.filepath(artifactpath))
			else
				print(sty.fail("\tFailed to write ") .. sty.filepath(artifactpath))
			end
		else
			print(sty.dim("\tSkipped"))
		end
		return created
	end

	local accepted = 0

	local acceptAll = false
	-- Process new snapshots

	for i, n in news do
		print(sty.bold(`\nNew Snapshot {i}/{#news}: `) .. sty.filepath(path.format(n.filepath)))
		print(sty.dim("\tNo .snap file exists. Actual output:"))
		print("")
		print(n.actual)
		print("")

		local ok = false
		if acceptAll then
			ok = updateArtifact("a", n.artifactpath, n.actual)
		else
			local choice = prompt(acceptAll)
			if choice == "A" then
				acceptAll = true
				choice = "a"
			end
			ok = updateArtifact(choice, n.artifactpath, n.actual)
		end

		accepted += if ok then 1 else 0
	end

	for i, f in failures do
		print(sty.bold(`\nSnapshot {i}/{#failures}: `) .. sty.filepath(path.format(f.filepath)))
		print("")
		print(f.diff)
		print("")
		local ok = false
		if acceptAll then
			ok = updateArtifact("a", f.artifactpath, f.actual)
		else
			local choice = prompt(acceptAll)
			if choice == "A" then
				acceptAll = true
				choice = "a"
			end
			ok = updateArtifact(choice, f.artifactpath, f.actual)
		end
		accepted += if ok then 1 else 0
	end

	return accepted
end

local update = {}

function update.updatesnapshot(result: snapty.snapresult, update: boolean, interactive: boolean)
	local hasNew = #result.new > 0
	local hasFailed = #result.failed > 0
	if hasNew or hasFailed then
		-- Auto-accept both failed and new output
		if update then
			acceptAll(result)
		elseif interactive then
			local accepted = acceptInteractive(result.failed, result.new)
			print(`\nUpdated {accepted} snapshot(s).`)
		else
			if hasNew then
				print(`\n{#result.new} new snapshot(s) found.`)
			end
			if hasFailed then
				print(`{#result.failed} snapshot(s) failed.`)
			end

			print(`Run with --interactive to review or --update to accept all`)
			ps.exit(1)
		end
	end
	ps.exit(0)
end

return table.freeze(update)
