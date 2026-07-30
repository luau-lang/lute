
local t = setmetatable({}, {
   __tostring = function() return "custom_value" end
})
print(3, "abc", false)
print(t)
