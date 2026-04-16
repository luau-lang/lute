# crypto

```luau
local crypto = require("@lute/crypto")
```

## Summary

| Function / Property | Description |
| :--- | :--- |
| [SecretBox](#secretbox) |  |
| [digest](#cryptodigest) |  |
| [password.hash](#cryptopasswordhash) |  |
| [password.verify](#cryptopasswordverify) |  |
| [secretbox.keygen](#cryptosecretboxkeygen) |  |
| [secretbox.open](#cryptosecretboxopen) |  |
| [secretbox.seal](#cryptosecretboxseal) |  |

---

## Types

### SecretBox

```luau
type SecretBox = {
	read ciphertext: buffer,
	read nonce: buffer,
	read key: buffer,
}
```

---

## Functions and Properties

### crypto.digest

```luau
(hash: Hash<any>, message: string | buffer) -> buffer
```

---

### crypto.password.hash

```luau
(password: string) -> buffer
```

---

### crypto.password.verify

```luau
(hash: buffer, password: string) -> boolean
```

---

### crypto.secretbox.keygen

```luau
() -> buffer
```

---

### crypto.secretbox.open

```luau
(box: SecretBox) -> buffer
```

---

### crypto.secretbox.seal

```luau
(message: string | buffer, key: buffer?) -> SecretBox
```

---
