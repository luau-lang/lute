local lintTypes = require("../types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")

local name = "empty_if_block"
local message = "Empty if block detected. Consider removing it or adding to it."
local target = "https://lute.luau.org/cli/lint/empty_if_block.html"

local function containsComment(trivia: { syntax.Trivia }): boolean
	for _, triv in trivia do
		if triv.tag ~= "whitespace" then
			return true
		end
	end
	return false
end

local function isBlockEmpty(
	block: syntax.AstStatBlock,
	commentsCount: boolean,
	leadingTrivia: { syntax.Trivia },
	trailingTrivia: { syntax.Trivia }
): boolean
	-- If the block has statements, it's not empty
	if #block.statements > 0 then
		return false
	end

	-- If comments_count is false, we consider blocks with only comments as empty
	if not commentsCount then
		return true
	end

	-- if comments_count is true, the block is not empty when it contains comments.
	if containsComment(leadingTrivia) or containsComment(trailingTrivia) then
		return false
	end

	return true
end

local function lint(
	ast: syntax.AstStatBlock,
	sourcepath: path.path?,
	context: lintTypes.RuleContext
): { lintTypes.LintViolation }
	-- Get the comments_count option from the rule configuration
	local commentsCount = false
	if context.options and context.options.comments_count then
		commentsCount = context.options.comments_count :: boolean
	end

	-- Find all if statements
	return query.findallfromroot(ast, utils.isStatIf):map(function(ifStat): lintTypes.LintViolation?
		-- Check if the then block is empty
		if
			isBlockEmpty(
				ifStat.thenblock,
				commentsCount,
				ifStat.thenkeyword.trailingtrivia,
				if #ifStat.elseifs > 0 -- trailingToken
					then ifStat.elseifs[1].elseifkeyword.leadingtrivia
					elseif ifStat.elsekeyword then ifStat.elsekeyword.leadingtrivia
					else ifStat.endkeyword.leadingtrivia
			)
		then
			return {
				lintname = name,
				location = ifStat.location,
				message = message,
				severity = "warning",
				sourcepath = sourcepath,
				target = target,
			}
		end

		-- Check elseif blocks
		for i, elseIfStat in ifStat.elseifs do
			if
				isBlockEmpty(
					elseIfStat.thenblock,
					commentsCount,
					elseIfStat.thenkeyword.trailingtrivia,
					if i < #ifStat.elseifs -- trailingToken
						then ifStat.elseifs[i + 1].elseifkeyword.leadingtrivia
						elseif ifStat.elsekeyword then ifStat.elsekeyword.leadingtrivia
						else ifStat.endkeyword.leadingtrivia
				)
			then
				return {
					lintname = name,
					location = ifStat.location,
					message = message,
					severity = "warning",
					sourcepath = sourcepath,
					target = target,
				}
			end
		end

		-- Check else block if it exists
		if ifStat.elseblock then
			assert(ifStat.elsekeyword, "elseblock should have an elsekeyword")
			if
				isBlockEmpty(
					ifStat.elseblock,
					commentsCount,
					ifStat.elsekeyword.trailingtrivia,
					ifStat.endkeyword.leadingtrivia
				)
			then
				return {
					lintname = name,
					location = ifStat.location,
					message = message,
					severity = "warning",
					sourcepath = sourcepath,
					target = target,
				}
			end
		end

		return nil
	end).nodes
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
