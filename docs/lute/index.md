---
order: 4
---

# (@lute) Lute Runtime Builtins
In addition to the [standard library](../std/), Lute also exposes a set of libraries under the `@lute` alias. These API's are written natively as part of the runtime, and provide the foundational capabilities (e.g. file system and network access, access to Luau internals, etc.) on which the standard library is build. In general, you should prefer to use the standard library modules in `@std` as those libraries are high-level enough that we believe they can be widely supported across Luau runtimes such as Roblox, Lute (this tool), and other game-engines. Using `@lute` libraries will make your code less portable as they will not be supported on Roblox environments.
