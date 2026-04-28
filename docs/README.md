# Editing Lute Documentation

Lute's docs are generated from Markdown files using [VitePress](https://vitepress.dev/).
To run the docsite locally, you should have Node.js and NPM installed.
Then, use the following to start running it locally:

1. `cd docs`
2. `npm install`
3. `npm run dev`

The terminal output should then tell you which `localhost` port the docsite is running at.

Note: Running `npm run dev` requires that you have `lute` on your `$PATH`.
If you don't, (or have `lute` set as an alias in your shell), you can run `<Path to lute executable> doc -m docgen.luau` directly instead.

## Regenerating documentation files

Run `npm run gen` from the `docs` folder to regenerate the reference content in `docs/std` and `docs/lute`. This uses `docgen.luau`, which maps `../lute/std/libs` to `docs/std` and `../definitions` to `docs/lute`.
