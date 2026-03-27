# crypto

```luau
local crypto = require("@lute/crypto")
```

## crypto.digest

testing the block comment without = here

```lua
(hash: { __hash: any }, message: buffer | string) -> (buffer)
```

## crypto.hash

```lua
{ blake2b256: { __hash: "blake2b256" }, md5: { __hash: "md5" }, sha1: { __hash: "sha1" }, sha256: { __hash: "sha256" }, sha512: { __hash: "sha512" } }
```

## crypto.password

```lua
{ hash: (password: string) -> (buffer), verify: (hash: buffer, password: string) -> (boolean) }
```

## crypto.secretbox

testing the block comment here

```lua
{ keygen: () -> (buffer), open: (box: { ciphertext: buffer, key: buffer, nonce: buffer }) -> (buffer), seal: (message: buffer | string, key: buffer?) -> ({ ciphertext: buffer, key: buffer, nonce: buffer }) }
```
