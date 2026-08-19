local returned, _data = xpcall(function()
	x("This will error")
end, function(_err)
	return "error found"
end)

local _test = returned
