print("1")
local result = require("@dep")
result[#result + 1] = "externally facing dep"
return result
