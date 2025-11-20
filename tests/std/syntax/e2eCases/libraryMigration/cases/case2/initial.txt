local oldLibraryDiffAlias = require(root.nested.packages.old)

local myEl = oldLibraryDiffAlias.oldFunction("lol")

return oldLibraryDiffAlias.anotherFunction(myEl)
