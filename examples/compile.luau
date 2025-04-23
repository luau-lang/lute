local luau = require("@lute/luau")

local bytecode_container = luau.compile('return "Hello, world!"')

print(`Bytecode is {#bytecode_container["bytecode"]} bytes long`)

print(luau.load(bytecode_container)())
