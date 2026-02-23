local json = require("@std/json")

local serialize = json.serialize({
	hello = "world",
}, true)

print(serialize)

local deserialized = json.deserialize([[{
    "hello": "world"
}]])
deserialized = assert(json.asobject(deserialized))
print(deserialized.hello)
