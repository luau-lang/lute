local crypto = {}

export type Hash<T> = { __hash: T }

crypto.hash = {
	md5 = {} :: Hash<"md5">,
	sha1 = {} :: Hash<"sha1">,
	sha256 = {} :: Hash<"sha256">,
	sha512 = {} :: Hash<"sha512">,
	blake2b256 = {} :: Hash<"blake2b256">,
}
crypto.password = {}

function crypto.digest(hash: Hash<any>, message: string | buffer): buffer
	error("not implemented")
end

function crypto.password.hash(password: string): buffer
	error("not implemented")
end

function crypto.password.verify(hash: buffer, password: string): boolean
	error("not implemented")
end

return crypto
