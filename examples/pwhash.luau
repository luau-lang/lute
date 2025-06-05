local crypto = require("@lute/crypto")

local secret = "woof"
local password = crypto.password.hash(secret)

function hexify(digest)
	local hex = {}
	for i = 1, buffer.len(digest) do
		hex[i] = string.format("%02x", buffer.readu8(digest, i - 1))
	end
	return table.concat(hex)
end

print(`password hash: {hexify(password)}`)
print(`matches woof: {crypto.password.verify(password, "woof")}`)
print(`matches bark: {crypto.password.verify(password, "bark")}`)
