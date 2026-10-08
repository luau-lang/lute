local function fresh()
    return { a = 1 }
end

-- This is not a literal (i.e a reference) - it should be considered used
local x = fresh()
x.a += 1


function foo()
    -- This is also a reference variable - it's not used either
    local x = fresh()
    x.a += 1
end

