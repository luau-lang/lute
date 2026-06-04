-- Benchmark the @batteries/toml deserializer against the toml-test corpus.
-- Run from the repo root:
--   lute tools/luthier run lute tools/bench-toml.luau

local toml = require("../batteries/toml")
local fs = require("@std/fs")

local function collectTomlFiles(dir: string, results: { string }): ()
	local entries = fs.listDirectory(dir)
	for _, entry in entries do
		local fullPath = `{dir}/{entry.name}`
		if entry.type == "dir" then
			collectTomlFiles(fullPath, results)
		elseif entry.type == "file" and string.match(entry.name, "%.toml$") then
			table.insert(results, fullPath)
		end
	end
end

local paths: { string } = {}
collectTomlFiles("extern/toml-test/tests/valid", paths)
collectTomlFiles("extern/toml-test/tests/invalid", paths)

-- Pre-read all files so I/O is excluded from timing
local contents: { string } = {}
for _, path in paths do
	local ok, data = pcall(fs.readFileToString, path)
	if ok then
		table.insert(contents, data :: string)
	end
end

local totalBytes = 0
for _, src in contents do
	totalBytes += #src
end

print(`Corpus: {#contents} files, {totalBytes} bytes total`)
print()

-- Warm-up pass
for _, src in contents do
	pcall(toml.deserialize, src)
end

local PASSES = 20

local t0 = os.clock()
for _ = 1, PASSES do
	for _, src in contents do
		pcall(toml.deserialize, src)
	end
end
local elapsed = os.clock() - t0

print(`Passes:      {PASSES}`)
print(`Total time:  {string.format("%.3f", elapsed)} s`)
print(`Per pass:    {string.format("%.1f", elapsed / PASSES * 1000)} ms`)
print(`Per file:    {string.format("%.3f", elapsed / PASSES / #contents * 1000)} ms avg`)
print(`Throughput:  {string.format("%.2f", totalBytes * PASSES / elapsed / 1024 / 1024)} MB/s`)
