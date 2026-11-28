const parseIgnores = require("./parseIgnores")
const path = require("@std/path")
const process = require("@std/process")

const function filter(configDir: string, patterns: { string }, sources: { string }): { string }
	const cwd = process.cwd()
	const ignores = parseIgnores.parseIgnoreContents(path.format(path.resolve(cwd, configDir)), patterns)
	const kept: { string } = {}
	for _, source in sources do
		const absolutePath = path.format(path.resolve(cwd, source))
		if not parseIgnores.isIgnored(ignores, absolutePath, false) then
			table.insert(kept, source)
		end
	end

	return kept
end

return filter(...)
