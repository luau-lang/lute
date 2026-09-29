local dispatch = { a = function() return 1 end }

local function basic(c)
	if local handler = dispatch[c] then
		return handler()
	end
	return nil
end

local function withConst(c)
	if const handler = dispatch[c] then
		return handler()
	end
	return nil
end

local function withAnnotation(t: { [string]: number }, k: string)
	if local value: number = t[k] then
		return value + 1
	end
	return 0
end

local function withElseif(c)
	if c == nil then
		return -1
	elseif local handler = dispatch[c] then
		return handler()
	else
		return 0
	end
end

return { basic, withConst, withAnnotation, withElseif }
