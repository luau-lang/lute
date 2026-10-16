local function pow(n: int)
	if n == 0 then
		return 1
	end
	return 2 * pow(n - 1)
end

pow(5)
