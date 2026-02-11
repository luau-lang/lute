function foo<A, B...>(_x: A, ...: B...)
	return nil :: any
end

local _x = foo<<string, number...>>("hello", 1, 2, 3)