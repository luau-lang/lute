return {
	sort = function(t)
		-- LUAUFIX - we cannot figure out the type of the array elements, even with an annotation on t.
		table.sort(t, function(a: number, b: number)
			return a < b
		end)
		return t
	end,
}
