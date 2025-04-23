local crypto = require("@lute/crypto")

local base64 = require("@batteries/base64")

local message = "Hello, world!"
local digest = crypto.digest(crypto.hash.sha256, message)

function pretty(digest)
    return buffer.tostring(base64.encode(digest))
end

print(pretty(digest))
