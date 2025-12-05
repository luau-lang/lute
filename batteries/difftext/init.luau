local myersdiff = require("@self/myersdiff")
local printdiff = require("@self/printdiff")

export type diff = myersdiff.diff

local function diff(
	a: string,
	b: string,
	options: {
		byChar: boolean?,
	}?
): diff
	if options and options.byChar then
		return myersdiff.myersdiffbychar(a, b)
	else
		return myersdiff.myersdiffbyline(a, b)
	end
end

return {
	diff = diff,
	printdiff = printdiff,
}
