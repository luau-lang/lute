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

--- Computes a cryptographic hash of `message` using the given `hash` algorithm. Returns the hash as a buffer.
function crypto.digest(hash: Hash<any>, message: string | buffer): buffer
	error("not implemented")
end

crypto.secretbox = {}

--- A sealed message containing the encrypted ciphertext, nonce, and key.
export type SecretBox = {
	read ciphertext: buffer,
	read nonce: buffer,
	read key: buffer,
}

--- Generates a new random secret key for use with `secretbox.seal`.
function crypto.secretbox.keygen(): buffer
	error("not implemented")
end

--- Encrypts `message` with `key` (or a freshly generated key if omitted). Returns a `SecretBox`.
function crypto.secretbox.seal(message: string | buffer, key: buffer?): SecretBox
	error("not implemented")
end

--- Decrypts `box` and returns the original plaintext as a buffer.
function crypto.secretbox.open(box: SecretBox): buffer
	error("not implemented")
end

crypto.password = {}

--- Hashes `password` using a slow, memory-hard algorithm suitable for password storage. Returns the hash as a buffer.
function crypto.password.hash(password: string): buffer
	error("not implemented")
end

--- Verifies that `password` matches the stored `hash`. Returns `true` if the password is correct.
function crypto.password.verify(hash: buffer, password: string): boolean
	error("not implemented")
end

return crypto
