local leftTrivia = require("@self/lefttrivia")
local rightTrivia = require("@self/righttrivia")

return table.freeze({
	leftmosttrivia = leftTrivia.leftmosttrivia,
	rightmosttrivia = rightTrivia.rightmosttrivia,
})
