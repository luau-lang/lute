local myersdiff = require("@self/myersdiff")
local printdiff = require("@self/printdiff")

export type diff = myersdiff.diff
export type applydiff = (string) -> string

local function diff(
	a: string,
	b: string,
	options: {
		byChar: boolean?,
	}?
): (diff, applydiff)
	if options and options.byChar then
		local diff = myersdiff.myersdiffbychar(a, b)
		return diff, function(a: string)
			return myersdiff.applydiff(diff, a, {
				byChar = true,
			})
		end
	else
		local diff = myersdiff.myersdiffbyline(a, b)

		return diff, function(a: string)
			return myersdiff.applydiff(diff, a)
		end
	end
end

return {
	diff = diff,
	printdiff = printdiff,
}
