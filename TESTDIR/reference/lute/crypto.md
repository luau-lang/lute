# crypto

```luau
local crypto = require("@lute/crypto")
```

## crypto.digest

testing the block comment without = here

```luau
({ __hash: any }, string | buffer) -> (buffer)
```

## crypto.hash

```luau
{ md5: { __hash: "md5" }, sha1: { __hash: "sha1" }, sha512: { __hash: "sha512" }, sha256: { __hash: "sha256" }, blake2b256: { __hash: "blake2b256" } }
```

## crypto.password

```luau
{ hash: (string) -> (buffer), verify: (buffer, string) -> (boolean) }
```

## crypto.secretbox

testing the block comment here

```luau
{ seal: (string | buffer, buffer | nil) -> ({ ciphertext: buffer, key: buffer, nonce: buffer }), open: ({ ciphertext: buffer, key: buffer, nonce: buffer }) -> (buffer), keygen: () -> (buffer) }
```
