-- lute-lint-global-ignore(unused_variable)

local t = { x = 1 }

-- if-local statement forms

if local handler = t.x then
	print(handler)
end

if const handler = t.x then
	print(handler)
end

if local value: number = t.x then
	print(value)
end

if t.x == nil then
	print("nil")
elseif local handler = t.x then
	print(handler)
else
	print("else")
end

-- if-local expression forms

local exprBasic = if local v = t.x then v else 0
local exprConst = if const v = t.x then v else 0
local exprAnnotation = if local v: number = t.x then v else 0
local exprElseif = if t.x == nil then -1 elseif local v = t.x then v else 0
