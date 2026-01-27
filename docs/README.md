# Editing Lute Documentation

Lute's docs are generated from using [VitePress](https://vitepress.dev/). To run the docsite locally, you should have Node.js and NPM installed. Then, use the following to start running it locally:

1. `cd docs`
2. `npm install`
3. `npx vitepress build`
4. `npm run preview`

The terminal output should then tell you which `localhost` port the docsite is running at.

## Regenerating documentation files

If you want to regenerate the documentation files in `docs/reference`, you will need to run `<path-to-lute> doc -o ./ ../definitions ../lute/std/libs` from the `docs` folder using a version of `lute` which supports `lute doc`.
