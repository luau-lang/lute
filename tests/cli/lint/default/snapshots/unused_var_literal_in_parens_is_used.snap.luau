-- Putting parens around a literal doesn't change that it's not used
local x = ({ a = 1 })
x.a += 1
