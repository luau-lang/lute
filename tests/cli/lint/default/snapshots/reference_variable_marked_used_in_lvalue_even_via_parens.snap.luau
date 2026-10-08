local function fresh()
    return { a = 1 }
end

-- Still should be marked used!
local x = (fresh())
x.a += 1
