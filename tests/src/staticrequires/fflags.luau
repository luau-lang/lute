-- This file should fail when LUTE_FFLAGS sets a low LuauSolverConstraintLimit
local total = 0
for _, value in { 1, 2, 3 } do
	total += value
end
return total
