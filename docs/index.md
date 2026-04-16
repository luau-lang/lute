---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Lute"
  text: "Run Luau Anywhere"
  # tagline: "A standalone runtime for general-purpose programming in Luau"
  image:
    src: /lute-logo.png
    alt: Lute logo
  actions:
    - theme: brand
      text: Getting Started
      link: /guide/installation
    - theme: alt
      text: Reference
      link: /std

features:
  - title: 🖥️ General-Purpose APIs
    details: "Lute provides a rich set of built-in APIs for common tasks: file system access, HTTP networking, cryptography, process management, and more."
  - title: 🛠️ First-Class Tooling
    details: "Lute includes a suite of tools, including a test runner, a linter, and the Luau type checker — all accessible through the `lute` CLI."
  - title:  👾 Compatible with Roblox
    details:  "Lute runs Luau code, just like Roblox, allowing you to easily run and test modules that don't depend on the game engine itself."
---

## What is Lute?

While [Luau](https://luau.org) is a powerful scripting language, it is sandboxed and primarily embedded in a larger program, like the Roblox game engine. This means
it lacks built-in capabilities for interacting with the outside world. Lute fills the gap by providing a standalone runtime for Luau, designed for general-purpose
programming outside of game engines. Think of it like [Node.js](https://nodejs.org/) or [Deno](https://deno.land/), but for Luau.

## How can I use it?

Lute provides a rich set of built-in APIs for common programming tasks: file system access, HTTP networking, cryptography, process management, and more.
You can use these APIs to build a wide variety of applications, from command-line tools to web servers to automation scripts and more. These capabilities come
in the form of a set of low-level libraries exposed to Luau under the `@lute` require alias, and a higher-level standard library built on top of those, exposed
under the `@std` alias. For Roblox developers, we're working hard to ensure the Roblox game engine will support this same set of `@std` APIs in the future, so you
can write code that runs both in Lute and Roblox with minimal changes.
