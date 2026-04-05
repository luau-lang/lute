--[[
Module to trim the diff of a file into hunks

Better solution is prob to do this at the printdiff level, but I didn't feel like doing all that yet 🫠
]]

local prettydiff = require("@batteries/difftext").prettydiff

local function getDiffType(line: string)
	-- Looks for + or -, followed by spaces, numbers, spaces, and a |
	return line:match("([%+%-])%s*%d+%s*|")
end

local function isDiffLine(line: string)
	return getDiffType(line) ~= nil
end

local PATCH_CONTEXT_LIMIT = 3
local function trimDiff(diff: string)
	--[[
        iterate thru diff
        keep track of diff hunks (where things actually changed) (we'll build a table of these and concat them at the end
    ]]
	local lines = string.split(diff, "\n")

	local inDiff = false
	local diffBuffer = 0
	local activeHunk: { string } = {}
	local hunks = {}
	for _, line in lines do
		if isDiffLine(line) then
			table.insert(activeHunk, line)
			inDiff = true
		elseif inDiff and diffBuffer < hunk_CONTEXT_LIMIT then
			table.insert(activeHunk, line)
			diffBuffer += 1
		else
			if inDiff then
				-- capture the hunk we're leaving
				table.insert(hunks, table.concat(activeHunk, "\n"))
			end
			inDiff, diffBuffer, activeHunk = false, 0, {}
		end
	end

	if inDiff then
		table.insert(hunks, table.concat(activeHunk, "\n"))
	end

	return table.concat(hunks, "\n...\n")
end

local function conciseDiff(a, b): string
	local diff = prettydiff(a, b, {
		includeLineNumbers = true,
	})

	return trimDiff(diff)
end

return conciseDiff
