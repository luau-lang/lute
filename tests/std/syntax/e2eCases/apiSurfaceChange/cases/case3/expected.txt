local sameLibrary = require(packagesRoot.sameLibrary)

local a = sameLibrary.processNumber(42)
local b = sameLibrary.processArray(table.unpack({ 10, 20, 30 }))
local c = sameLibrary.handleText("hello")
