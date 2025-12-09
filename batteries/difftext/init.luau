local myersdiff = require("@self/myersdiff")
local printdiff = require("@self/printdiff")
local types = require("@self/types")

export type diff = types.diff
export type diffoptions = types.diffoptions

local function diff(a: string, b: string, options: diffoptions): diff
	if options and options.byChar then
		return myersdiff.myersdiffbychar(a, b)
	else
		return myersdiff.myersdiffbyline(a, b)
	end
end

return {
	diff = diff,
	prettydiff = printdiff,
}
