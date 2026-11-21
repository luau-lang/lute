local fs = require("@std/fs")
local internalTypes = require("./internaltypes")
local lintCore = require("./lintCore")
local parseIgnores = require("../lib/parseIgnores")
local pathLib = require("@std/path")
local system = require("@std/system")
local task = require("@std/task")
local types = require("@lint")
local vm = require("@lute/vm")

local lint = {}

function lint.lintSequential(
	inputFiles: { pathLib.Path },
	lintRules: { types.LintRule },
	configData: internalTypes.RuleConfigData,
	autofixEnabled: boolean,
	ignoreData: parseIgnores.GitignoreData,
	verbose: boolean
): ({ [pathLib.Path]: { types.LintViolation } }, boolean)
	local allViolations = {}
	local failed = false
	local hasIgnores = #ignoreData.ignores > 0
	for _, inputPath in inputFiles do
		local walker = fs.walk(inputPath, { recursive = true })

		local curr = walker()
		while curr ~= nil do
			if hasIgnores then
				local inputFilePathString = pathLib.format(curr)

				if parseIgnores.isIgnored(ignoreData, inputFilePathString, fs.type(inputFilePathString) == "dir") then
					curr = walker()
					continue
				end
			end

			local success, err, ruleFailed =
				pcall(lintCore.lintFile, curr, lintRules, autofixEnabled, configData, verbose)
			if success then
				-- Violations are returned as the second return value from pcall
				allViolations[curr] = err
				failed = failed or ruleFailed
			else
				print(`Error linting file '{curr}': {err}`)
				failed = true
			end

			curr = walker()
		end
	end
	return allViolations, failed
end

type Job = {
	inputFile: pathLib.Path,
	autoFixEnabled: boolean,
}

function lint.lintParallel(
	inputFiles: { pathLib.Path },
	rulesPath: string?,
	noDefaults: boolean,
	passedConfigVal: string?,
	autofixEnabled: boolean,
	ignoreData: parseIgnores.GitignoreData,
	verbose: boolean
): ({ [pathLib.Path]: { types.LintViolation } }, boolean)
	local allViolations = {}
	local failed = false
	local hasIgnores = #ignoreData.ignores > 0
	local maxWorkers = math.min(system.threadCount(), #inputFiles)
	local curJob = 1
	local doneWorkers = 0

	local function lintNext(): Job?
		if curJob > #inputFiles then
			return nil
		end

		local nextJob: Job = {
			inputFile = inputFiles[curJob],
			autoFixEnabled = autofixEnabled,
		}

		curJob += 1

		return nextJob
	end

	local function spawnWorker()
		task.spawn(function()
			xpcall(function()
				local worker = vm.create("./worker")
				-- Initialize will be UNNECESSARY once we can pass functions to separate VM
				-- Once that is the case:
				-- 		remove initialize
				-- 		refactor to omit rulesPath / passedConfigVal and instead pass lintRules / configData directly to lintFile
				worker.initialize(rulesPath, noDefaults, passedConfigVal, verbose)

				local activeJob = lintNext()
				while activeJob ~= nil do
					local job = activeJob :: Job
					local inputFilePathString = pathLib.format(activeJob.inputFile)
					local isIgnored = hasIgnores and parseIgnores.isIgnored(ignoreData, inputFilePathString, false)
					if not isIgnored then
						local success, res, ruleFailed = pcall(function()
							return worker.lintFile(inputFilePathString, job.autoFixEnabled, verbose)
						end)
						if success then
							allViolations[activeJob.inputFile] = res :: { types.LintViolation }
							failed = failed or ruleFailed == true
						else
							print(`(worker) Error linting file '{activeJob.inputFile}': {res}`)
							failed = true
						end
					end
					activeJob = lintNext()
				end
			end, function(err: any)
				print(`worker errored: {tostring(err)}`)
				failed = true
			end)

			doneWorkers += 1
		end)
	end

	for _ = 1, maxWorkers do
		spawnWorker()
	end

	while doneWorkers < maxWorkers do
		task.wait() -- wait for all jobs to run
	end

	return allViolations, failed
end

return table.freeze(lint)
