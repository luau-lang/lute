local credentialProvider = require("@commands/pkg/loom-core/src/credentialprovider")

local protocol, host, repositoryPath, expectedToken = select(2, ...)
local token = credentialProvider.resolveToken(table.freeze({
	protocol = protocol,
	host = host,
	path = repositoryPath,
}))

if expectedToken == "<nil>" then
	assert(token == nil, `Expected no token, got {token}`)
else
	assert(token == expectedToken, `Expected token {expectedToken}, got {token}`)
end
