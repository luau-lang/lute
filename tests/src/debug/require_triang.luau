local M = {}
function M.triangular(x: number)
	local result = 0
	for i = 1, x do
		result += i
	end
	return result
end
return M
