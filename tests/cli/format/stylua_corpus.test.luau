const difftext = require("../../../batteries/difftext")
const format = require("@commands/format/format")
const fs = require("@std/fs")
const path = require("@std/path")
const process = require("@std/process")
const test = require("@std/test")

const denylist = require("./stylua_denylist")
const testutil = require("../../testutil")

const CORPUS_ROOT = path.join(process.cwd(), "tests", "cli", "format", "stylua")
const SNAPSHOT_MARKER = "\n---\n"
const SUITES = table.freeze({
	{ name = "inputs", snapshotPrefix = "tests__standard@" },
	{ name = "inputs-full_moon", snapshotPrefix = "tests__full_moon_test_suite@" },
	{ name = "inputs-luau", snapshotPrefix = "tests__luau@" },
	{ name = "inputs-luau-full_moon", snapshotPrefix = "tests__luau_full_moon@" },
})

type Case = {
	read id: string,
	read inputPath: string,
	read snapshotPath: string,
}

const function readSnapshot(snapshotPath: string): string
	const snapshot = testutil.normalizeLineEndings(fs.readFileToString(snapshotPath))
	const _, headerEnd = snapshot:find(SNAPSHOT_MARKER, 1, true)
	if headerEnd == nil then
		error(`Invalid insta snapshot: {snapshotPath}`)
	end
	return snapshot:sub(headerEnd + 1)
end

const function formatCase(case: Case): string
	const source = testutil.normalizeLineEndings(fs.readFileToString(case.inputPath))
	return format.formatSource(source)
end

const function listCases(): { Case }
	const cases: { Case } = {}
	for _, suite in SUITES do
		const names: { string } = {}
		for _, entry in fs.listDirectory(path.join(CORPUS_ROOT, suite.name)) do
			if entry.type == "file" and string.sub(entry.name, -4) == ".lua" then
				table.insert(names, entry.name)
			end
		end
		table.sort(names)
		for _, filename in names do
			table.insert(
				cases,
				table.freeze({
					id = `{suite.name}/{filename}`,
					inputPath = path.format(path.join(CORPUS_ROOT, suite.name, filename)),
					snapshotPath = path.format(
						path.join(CORPUS_ROOT, "snapshots", `{suite.snapshotPrefix}{filename}.snap`)
					),
				})
			)
		end
	end
	return table.freeze(cases)
end

const cases = listCases()
const casesById: { [string]: Case } = {}
for _, case in cases do
	casesById[case.id] = case
end
table.freeze(casesById)

const denied: { [string]: boolean } = {}
for _, caseId in denylist do
	denied[caseId] = true
end
table.freeze(denied)

test.suite("StyLuaCorpus", function(suite)
	suite:case("corpus and snapshots are valid", function(assert)
		const expectedSnapshots: { [string]: boolean } = {}
		for _, case in cases do
			assert.that(fs.exists(case.snapshotPath), `Missing StyLua snapshot: {case.snapshotPath}`)
			expectedSnapshots[case.snapshotPath] = true
		end

		for _, entry in fs.listDirectory(path.join(CORPUS_ROOT, "snapshots")) do
			if entry.type == "file" and string.sub(entry.name, -5) == ".snap" then
				const snapshotPath = path.format(path.join(CORPUS_ROOT, "snapshots", entry.name))
				assert.that(expectedSnapshots[snapshotPath] == true, `Orphan StyLua snapshot: {entry.name}`)
			end
		end
	end)

	suite:case("denylist cases are valid", function(assert)
		const seen: { [string]: boolean } = {}
		for _, caseId in denylist do
			assert.that(not seen[caseId], `Duplicate StyLua case: {caseId}`)
			seen[caseId] = true
			assert.that(casesById[caseId] ~= nil, `Unknown StyLua case: {caseId}`)
		end
	end)

	suite:case("denylist cases are failing", function(assert)
		const nowPassing: { string } = {}
		for _, caseId in denylist do
			const case = casesById[caseId]
			if case ~= nil then
				const ok, actual = pcall(formatCase, case)
				if ok and actual == readSnapshot(case.snapshotPath) then
					table.insert(nowPassing, caseId)
				end
			end
		end
		assert.eq(#nowPassing, 0, `Remove these cases from stylua_denylist.luau:\n{table.concat(nowPassing, "\n")}`)
	end)

	for _, case in cases do
		if denied[case.id] then
			continue
		end

		suite:case(case.id, function(assert)
			const expected = readSnapshot(case.snapshotPath)
			const actual = formatCase(case)

			const diff = difftext.prettydiff(expected, actual, {
				detailed = true,
				includeLineNumbers = true,
			})
			assert.eq(actual, expected, `StyLua output mismatch:\n{diff}`)
			assert.eq(format.formatSource(actual), actual, "Formatter output is not idempotent")
		end)
	end
end)
