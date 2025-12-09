local richterm = require("@batteries/richterm")
local myersdiff = require("./myersdiff")
local myersdiffbychar = myersdiff.myersdiffbychar
local myersdiffbyline = myersdiff.myersdiffbyline
local types = require("./types")
local brightGreen = richterm.brightGreen
local brightRed = richterm.brightRed
local bgGreen = richterm.bgGreen
local bgRed = richterm.bgRed

type diff = types.diff

-- Collects consecutive DELETEs and/or ADDs starting at index i
-- Returns: deletes array, adds array, new index position
local function collectConsecutiveChanges(diff: diff, startIndex: number): ({ string }, { string }, number)
	local i = startIndex
	local deletes = {}
	while i <= #diff and diff[i].key == "DELETE" do
		table.insert(deletes, diff[i].text)
		i += 1
	end

	local adds = {}
	while i <= #diff and diff[i].key == "ADD" do
		table.insert(adds, diff[i].text)
		i += 1
	end

	return deletes, adds, i
end

local function visualizeCharDiff(a: string, b: string): (string, string)
	local charOps = myersdiffbychar(a, b)
	-- diffs two strings by char and returns colored visual for src and destination text
	local srcVisual = {}
	local destVisual = {}

	for _, op in charOps do
		if op.key == "EQUAL" then
			table.insert(srcVisual, brightRed(op.text))
			table.insert(destVisual, brightGreen(op.text))
		elseif op.key == "DELETE" then
			table.insert(srcVisual, bgRed(op.text))
		elseif op.key == "ADD" then
			table.insert(destVisual, bgGreen(op.text))
		end
	end

	return table.concat(srcVisual, ""), table.concat(destVisual, "")
end

local function formatLineSideHeader(
	operation: types.diffoperationkey,
	maxNumWidth: number?,
	lineNumbers: {
		oldLine: number?,
		newLine: number?,
	}?
): string
	-- side header structure:
	-- 	  if line numbers included:
	-- 		ALWAYS has length maxNumWidth*2 + 4
	-- 		the padded structure is essentialy:
	--		{operation} {oldLine# padded to len of maxNumWidth} {newLine# padded to len = maxNumWidth}|
	-- 	  if line numbers excluded:
	-- 		"+ " for additions, "- " for deletions, "" for equality

	local function padding(width: number)
		return (" "):rep(width)
	end

	local oldStr = tostring(if lineNumbers then lineNumbers.oldLine else "")
	local newStr = tostring(if lineNumbers then lineNumbers.newLine else "")
	maxNumWidth = maxNumWidth or 1
	if operation == "EQUAL" then
		if not lineNumbers then
			return ""
		end
		local leftPad = maxNumWidth - #oldStr
		local rightPad = maxNumWidth - #newStr
		return string.format("  %s%s %s%s| ", padding(leftPad), oldStr, padding(rightPad), newStr)
	elseif operation == "ADD" then
		if not lineNumbers then
			return "+ "
		end
		local leftPad = maxNumWidth -- space for missing oldLine
		local rightPad = maxNumWidth - #newStr
		return string.format("+ %s %s%s| ", padding(leftPad), padding(rightPad), newStr)
	elseif operation == "DELETE" then
		if not lineNumbers then
			return "- "
		end
		local leftPad = maxNumWidth - #oldStr
		local rightPad = maxNumWidth -- space for missing newLine
		return string.format("- %s%s %s| ", padding(leftPad), oldStr, padding(rightPad))
	end

	return "" -- unreachable
end

local function printDiffByLineDetailed(a: string, b: string, includeLineNumbers: boolean?): string
	local maxNumLines = math.max(#a:split("\n"), #b:split("\n"))
	local maxLineNumberLen = #tostring(maxNumLines)
	local diff = myersdiffbyline(a, b)

	local i = 1
	local result: { string } = {}
	local oldLine, newLine = 1, 1

	-- Helper to format line numbers
	local function lineNums(old: number?, new: number?)
		return { oldLine = old, newLine = new }
	end

	while i <= #diff do
		local op = diff[i]

		if op.key == "DELETE" or op.key == "ADD" then
			local deletes, adds
			deletes, adds, i = collectConsecutiveChanges(diff, i)
			local pair = #deletes == 1 and #adds == 1
			if pair then
				local srcLine, destLine = visualizeCharDiff(deletes[1], adds[1])
				if includeLineNumbers then
					table.insert(
						result,
						brightRed(formatLineSideHeader("DELETE", maxLineNumberLen, lineNums(oldLine, nil))) .. srcLine
					)
					table.insert(
						result,
						brightGreen(formatLineSideHeader("ADD", maxLineNumberLen, lineNums(nil, newLine))) .. destLine
					)
					oldLine, newLine = oldLine + 1, newLine + 1
				else
					table.insert(result, brightRed(formatLineSideHeader("DELETE")) .. srcLine)
					table.insert(result, brightGreen(formatLineSideHeader("ADD")) .. destLine)
				end
			else
				for j, deleted in deletes do
					if includeLineNumbers then
						table.insert(
							result,
							brightRed(
								formatLineSideHeader("DELETE", maxLineNumberLen, lineNums(oldLine, nil)) .. deleted
							)
						)
						oldLine += 1
					else
						table.insert(result, brightRed(formatLineSideHeader("DELETE") .. deleted))
					end
				end
				for j, added in adds do
					if includeLineNumbers then
						table.insert(
							result,
							brightGreen(formatLineSideHeader("ADD", maxLineNumberLen, lineNums(nil, newLine)) .. added)
						)
						newLine += 1
					else
						table.insert(result, brightGreen(formatLineSideHeader("ADD") .. added))
					end
				end
			end
		else -- EQUAL
			table.insert(
				result,
				if includeLineNumbers
					then formatLineSideHeader("EQUAL", maxLineNumberLen, lineNums(oldLine, newLine)) .. op.text
					else formatLineSideHeader("EQUAL") .. op.text
			)
			oldLine, newLine = oldLine + 1, newLine + 1
			i += 1
		end
	end
	return table.concat(result, "\n")
end

local function prettydiff(
	a: string,
	b: string,
	options: {
		detailed: boolean?,
		includeLineNumbers: boolean?,
	}?
): string
	if options and options.detailed then
		return printDiffByLineDetailed(a, b, options.includeLineNumbers)
	end

	local result = {} :: { string }
	local diff = myersdiffbyline(a, b)
	local maxNumLines = math.max(#a:split("\n"), #b:split("\n"))
	local maxLineNumberLen = #tostring(maxNumLines)
	local oldLine, newLine = 1, 1

	if options and options.includeLineNumbers then
		-- Helper to format line number tables so we don't get too verbose
		local function lineNums(old: number?, new: number?)
			return { oldLine = old, newLine = new }
		end

		for i, op in diff do
			if op.key == "ADD" then
				table.insert(
					result,
					brightGreen(formatLineSideHeader(op.key, maxLineNumberLen, lineNums(nil, newLine)) .. op.text)
				)
				newLine += 1
			elseif op.key == "DELETE" then
				table.insert(
					result,
					brightRed(formatLineSideHeader(op.key, maxLineNumberLen, lineNums(oldLine, nil)) .. op.text)
				)
				oldLine += 1
			else -- EQUAL
				table.insert(
					result,
					formatLineSideHeader(op.key, maxLineNumberLen, lineNums(oldLine, newLine)) .. op.text
				)
				oldLine, newLine = oldLine + 1, newLine + 1
			end
		end
	else
		for i, op in diff do
			if op.key == "ADD" then
				table.insert(result, brightGreen(formatLineSideHeader(op.key) .. op.text))
			elseif op.key == "DELETE" then
				table.insert(result, brightRed(formatLineSideHeader(op.key) .. op.text))
			else -- EQUAL
				table.insert(result, formatLineSideHeader(op.key) .. op.text)
			end
		end
	end
	return table.concat(result, "\n")
end

return prettydiff
