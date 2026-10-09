-- Putting parens around a literal doesn't change that it's not used
--stylua: ignore
local x = ({ a = 1 })
x.a += 1
