local ok, err = pcall(function()
	local y = nil
	return y.foo
end)

local z = nil
print(z.foo)
