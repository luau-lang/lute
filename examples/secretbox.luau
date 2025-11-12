local crypto = require("@lute/crypto")

local message = "Hello, world!"
local box = crypto.secretbox.seal(message)

function hexify(digest)
	local hex = {}
	for i = 1, buffer.len(digest) do
		hex[i] = string.format("%02x", buffer.readu8(digest, i - 1))
	end
	return table.concat(hex)
end

print(hexify(box.ciphertext))

local opened = crypto.secretbox.open(box)
local output = buffer.readstring(opened, 0, buffer.len(opened))

print(output)
assert(output == message)
