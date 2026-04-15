---
order: 4
---

# (@lute) Lute Runtime Builtins
Lute also exposes a second set of libraries under the `@lute` alias. These apis
usually expose runtime specific details or other internal functionality. Where
necessary, the standard library functionality has been implemented in terms of
@lute, so as much as possible, we encourage you to write code against `@std`.