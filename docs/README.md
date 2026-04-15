# Editing Lute Documentation

Lute's docs are generated from using [VitePress](https://vitepress.dev/). To run the docsite locally, you should have Node.js and NPM installed. Then, use the following to start running it locally:

1. `cd docs`
2. `npm install`
3. `npx vitepress build`
4. `npm run preview`

The terminal output should then tell you which `localhost` port the docsite is running at.

## Regenerating documentation files

Run `npm run gen` from the `docs` folder to regenerate the reference content in `docs/std` and `docs/lute`. This uses `docgen.luau`, which maps `../lute/std/libs` to `docs/std` and `../definitions` to `docs/lute`.
