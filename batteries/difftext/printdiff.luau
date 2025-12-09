local richterm = require("@batteries/richterm")
local myersdiff = require("./myersdiff")
local myersdiffbychar = myersdiff.myersdiffbychar
local myersdiffbyline = myersdiff.myersdiffbyline
local types = require("./types")

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
			table.insert(srcVisual, richterm.brightRed(op.text))
			table.insert(destVisual, richterm.brightGreen(op.text))
		elseif op.key == "DELETE" then
			table.insert(srcVisual, richterm.bgRed(op.text))
		elseif op.key == "ADD" then
			table.insert(destVisual, richterm.bgGreen(op.text))
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
	-- 		ALWAYS has length maxNumWidth*2 + 4
	-- 		the padded structure is essentialy:
	--{operation} {oldLine# padded to len of maxNumWidth} {newLine# padded to len = maxNumWidth}|

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
		return ("  %s%s %s%s| "):format(padding(leftPad), oldStr, padding(rightPad), newStr)
	elseif operation == "ADD" then
		if not lineNumbers then
			return "+ "
		end
		local leftPad = maxNumWidth -- space for missing oldLine
		local rightPad = maxNumWidth - #newStr
		return ("+ %s %s%s| "):format(padding(leftPad), padding(rightPad), newStr)
	elseif operation == "DELETE" then
		if not lineNumbers then
			return "- "
		end
		local leftPad = maxNumWidth - #oldStr
		local rightPad = maxNumWidth -- space for missing newLine
		return ("- %s%s %s| "):format(padding(leftPad), oldStr, padding(rightPad))
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
				table.insert(
					result,
					if includeLineNumbers
						then richterm.brightRed(
							formatLineSideHeader("DELETE", maxLineNumberLen, lineNums(oldLine, nil))
						) .. srcLine
						else richterm.brightRed(formatLineSideHeader("DELETE")) .. srcLine
				)
				table.insert(
					result,
					if includeLineNumbers
						then richterm.brightGreen(formatLineSideHeader("ADD", maxLineNumberLen, lineNums(nil, newLine)))
							.. destLine
						else richterm.brightGreen(formatLineSideHeader("ADD")) .. destLine
				)
				oldLine, newLine = oldLine + 1, newLine + 1
			else
				for j, deleted in deletes do
					table.insert(
						result,
						if includeLineNumbers
							then richterm.brightRed(
								formatLineSideHeader("DELETE", maxLineNumberLen, lineNums(oldLine, nil)) .. deleted
							)
							else richterm.brightRed(formatLineSideHeader("DELETE") .. deleted)
					)
					oldLine += 1
				end
				for j, added in adds do
					table.insert(
						result,
						if includeLineNumbers
							then richterm.brightGreen(
								formatLineSideHeader("ADD", maxLineNumberLen, lineNums(nil, newLine)) .. added
							)
							else richterm.brightGreen(formatLineSideHeader("ADD") .. added)
					)
					newLine += 1
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

	-- Helper to format line number tables so we don't get too verbose
	local function lineNums(old: number?, new: number?)
		return { oldLine = old, newLine = new }
	end

	for i, op in diff do
		if op.key == "ADD" then
			table.insert(
				result,
				if options and options.includeLineNumbers
					then richterm.brightGreen(
						formatLineSideHeader(op.key, maxLineNumberLen, lineNums(nil, newLine)) .. op.text
					)
					else richterm.brightGreen(formatLineSideHeader(op.key) .. op.text)
			)
			newLine += 1
		elseif op.key == "DELETE" then
			table.insert(
				result,
				if options and options.includeLineNumbers
					then richterm.brightRed(
						formatLineSideHeader(op.key, maxLineNumberLen, lineNums(oldLine, nil)) .. op.text
					)
					else richterm.brightRed(formatLineSideHeader(op.key) .. op.text)
			)
			oldLine += 1
		else
			table.insert(
				result,
				if options and options.includeLineNumbers
					then formatLineSideHeader(op.key, maxLineNumberLen, lineNums(oldLine, newLine)) .. op.text
					else formatLineSideHeader(op.key) .. op.text
			)
			oldLine, newLine = oldLine + 1, newLine + 1
		end
	end
	return table.concat(result, "\n")
end

return prettydiff
