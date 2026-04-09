# crypto

```luau
local crypto = require("@lute/crypto")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [digest](#cryptodigest) | testing the block comment without = here |
| [hash](#cryptohash) |  |
| [password](#cryptopassword) |  |
| [secretbox](#cryptosecretbox) | testing the block comment here |

---

## Types

### Hash
```luau
type Hash = { __hash: generic }
```

### SecretBox
```luau
type SecretBox = { ciphertext: buffer, key: buffer, nonce: buffer }
```

## Properties and Functions

## crypto.digest
```luau
function digest(hash: { __hash: any }, message: buffer | string) -> (buffer)
```
testing the block comment without = here

---

## crypto.hash
```luau
{ blake2b256: { __hash: "blake2b256" }, md5: { __hash: "md5" }, sha1: { __hash: "sha1" }, sha256: { __hash: "sha256" }, sha512: { __hash: "sha512" } }
```
---

## crypto.password
```luau
function password{ hash: (password: string) -> (buffer), verify: (hash: buffer, password: string) -> (boolean) }
```
---

## crypto.secretbox
```luau
function secretbox{ keygen: () -> (buffer), open: (box: { ciphertext: buffer, key: buffer, nonce: buffer }) -> (buffer), seal: (message: buffer | string, key: buffer?) -> ({ ciphertext: buffer, key: buffer, nonce: buffer }) }
```
testing the block comment here

---
