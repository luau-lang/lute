# crypto

```luau
local crypto = require("@lute/crypto")
```

## crypto.digest

testing the block comment without = here

```luau
(hash: { __hash: any }, message: string | buffer) -> (buffer)
```

## crypto.hash

```luau
{ md5: { __hash: "md5" }, sha1: { __hash: "sha1" }, sha512: { __hash: "sha512" }, sha256: { __hash: "sha256" }, blake2b256: { __hash: "blake2b256" } }
```

## crypto.password

```luau
{ hash: (password: string) -> (buffer), verify: (hash: buffer, password: string) -> (boolean) }
```

## crypto.secretbox

testing the block comment here

```luau
{ seal: (message: string | buffer, key: buffer | nil) -> ({ ciphertext: buffer, key: buffer, nonce: buffer }), open: (box: { ciphertext: buffer) -> (buffer), keygen: () -> (buffer) }
```
