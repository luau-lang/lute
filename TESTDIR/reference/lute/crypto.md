# crypto

```luau
local crypto = require("@lute/crypto")
```

## crypto.digest

```luau
(hash: Hash<any>, message: string | buffer) -> buffer
```

## crypto.password.hash

```luau
(password: string) -> buffer
```

## crypto.password.verify

```luau
(hash: buffer, password: string) -> boolean
```

## crypto.secretbox.keygen

testing the block comment here

```luau
() -> buffer
```

## crypto.secretbox.open

```luau
(box: SecretBox) -> buffer
```

## crypto.secretbox.seal

```luau
(message: string | buffer, key: buffer?) -> SecretBox
```
