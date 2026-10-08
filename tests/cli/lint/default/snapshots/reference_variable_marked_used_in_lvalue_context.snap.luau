local function fresh()
    return { a = 1 }
end

-- This should be considered 'used'
local x = fresh()
x.a += 1