local myersdiff = require("./difftext/myersdiff")
local printdiff = require("./difftext/printdiff")

export type Diff = myersdiff.Diff
export type ApplyDiff = (string) -> string

local function diff(
	a: string,
	b: string,
	options: {
		byChar: boolean?,
	}?
): (Diff, ApplyDiff)
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
