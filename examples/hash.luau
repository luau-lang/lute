local crypto = require("@lute/crypto")

local base64 = require("@batteries/base64")

local message = "Hello, world!"
local digest = crypto.digest(crypto.hash.sha256, message)

function hexify(digest)
	local hex = {}
	for i = 1, buffer.len(digest) do
		hex[i] = string.format("%02x", buffer.readu8(digest, i - 1))
	end
	return table.concat(hex)
end

function pretty(digest)
	return buffer.tostring(base64.encode(digest))
end

print(hexify(digest))
print(pretty(digest))
