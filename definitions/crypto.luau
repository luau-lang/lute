-- lute-lint-global-ignore(unused_variable)
local crypto = {}

export type Hash<T> = { __hash: T }

crypto.hash = table.freeze({
	md5 = {} :: Hash<"md5">,
	sha1 = {} :: Hash<"sha1">,
	sha256 = {} :: Hash<"sha256">,
	sha512 = {} :: Hash<"sha512">,
	blake2b256 = {} :: Hash<"blake2b256">,
})

function crypto.digest(hash: Hash<any>, message: string | buffer): buffer
	error("not implemented")
end

crypto.secretbox = {}

export type Secretbox = {
	read ciphertext: buffer,
	read nonce: buffer,
	read key: buffer,
}

function crypto.secretbox.keygen(): buffer
	error("not implemented")
end

function crypto.secretbox.seal(message: string | buffer, key: buffer?): Secretbox
	error("not implemented")
end

function crypto.secretbox.open(box: Secretbox): buffer
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
