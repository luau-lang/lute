-- lute-lint-global-ignore(unused_variable)
local crypto = {}

export type hash<T> = { __hash: T }

crypto.hash = table.freeze({
	md5 = {} :: hash<"md5">,
	sha1 = {} :: hash<"sha1">,
	sha256 = {} :: hash<"sha256">,
	sha512 = {} :: hash<"sha512">,
	blake2b256 = {} :: hash<"blake2b256">,
})

--[[
	testing the block comment without = here
]]
function crypto.digest(hash: hash<any>, message: string | buffer): buffer
	error("not implemented")
end

crypto.secretbox = {}

export type secretbox = {
	read ciphertext: buffer,
	read nonce: buffer,
	read key: buffer,
}

--[=[
	testing the block comment here
]=]
function crypto.secretbox.keygen(): buffer
	error("not implemented")
end

function crypto.secretbox.seal(message: string | buffer, key: buffer?): secretbox
	error("not implemented")
end

function crypto.secretbox.open(box: secretbox): buffer
	error("not implemented")
end

crypto.password = {}

function crypto.password.hash(password: string): buffer
	error("not implemented")
end

function crypto.password.verify(hash: buffer, password: string): boolean
	error("not implemented")
end

return crypto
