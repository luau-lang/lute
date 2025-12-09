-- test that we can require using an alias from other/.luaurc
local example = require("@otherlib/example")
print(`Required {example.file} from alias @otherlib`)

return {
	example = example,
}
