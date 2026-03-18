local path = require("@std/path")
local process = require("@std/process")

local TYPEDEFS_VERSION = "0.1.0"
local TYPEDEFS_BASE_DIR = `.lute/typedefs/{TYPEDEFS_VERSION}`
local TYPEDEFS_RELATIVE_DIR = `~/{TYPEDEFS_BASE_DIR}`
local TYPEDEFS_PATH = path.join(process.homedir(), TYPEDEFS_BASE_DIR)

local TEMPLATE_RC_FILE: { [any]: any } = {
	aliases = {
		lint = `{TYPEDEFS_RELATIVE_DIR}/lint`,
		lute = `{TYPEDEFS_RELATIVE_DIR}/lute`,
		std = `{TYPEDEFS_RELATIVE_DIR}/std`,
	},
}

local function indent(level: number)
	return string.rep("\t", level)
end

local function nest(src, parenIndent)
	return `\{\n{src}\n{parenIndent}\}`
end

local function kv(k, v, desc: string?)
	local kvpair = `{k} = {v}`
	if desc then
		kvpair = kvpair .. `, -- {desc}`
	end
	return kvpair
end

local function tbl(fields: { { value: string, description: string } } | { string }, level)
	local buf: { string } = {}
	local fieldIndent = indent(level + 1)
	local parenIndent = indent(level)
	for _, f in fields do
		if typeof(f) == "string" then
			table.insert(buf, `{fieldIndent}{f},`)
		else
			table.insert(buf, `{fieldIndent}-- {f.description}`)
			table.insert(buf, `{fieldIndent}{f.value},`)
		end
	end

	return nest(table.concat(buf, "\n"), parenIndent)
end

local function generateLuauConfig(languageMode: "strict" | "nonstrict"): string
	local aliases = {
		kv("lute", `"{TYPEDEFS_RELATIVE_DIR}/lute"`),
		kv("std", `"{TYPEDEFS_RELATIVE_DIR}/std"`),
		kv("lint", `"{TYPEDEFS_RELATIVE_DIR}/lint"`),
	}
	local aliasTable = tbl(aliases, 2)
	local luau = tbl({
		{
			value = kv("languagemode", `"{languageMode}"`),
			description = "Default language mode to use for typechecking",
		},
		{ value = kv("aliases", aliasTable), description = "Aliases for builtin libraries" },
	}, 1)
	return luau
end

local function generateLuteConfig(): string
	local ruleconfigs = tbl({
		`-- [RuleName] : \{`,
		`-- Array of globbed strings, representing paths exempt from this rule`,
		`-- ignores: \{string\}?`,
		`-- Override a rule's default severity`,
		`-- severity: ("warn" | "error" | "info" | "hint")?`,
		`-- Pass custom options through to a rule`,
		`-- options: \{ [string]: unknown \}?`,
		`-- Disable this rule`,
		`-- off: boolean?`,
		`-- \}`,
	}, 3)
	local lint = tbl({
		{
			value = kv("ignores", "{}"),
			description = "Array of globbed strings, representing paths to exempt from linting",
		},
		{ value = kv("globals", "{}"), description = "Global values passed to each linting rule" },
		{ value = kv("rulepaths", "{}"), description = "Array of strings from which to load local lint rules" },
		{
			value = kv("ruleconfigs", ruleconfigs),
			description = "Per rule overrides, with schema [RuleName] : {...}, where the schema is described below ",
		},
	}, 2)
	local lute = tbl({ kv("lint", lint) }, 1)
	return lute
end

local typedefs = {}

typedefs.TYPEDEFS_PATH = TYPEDEFS_PATH
typedefs.TYPEDEFS_RELATIVE_DIR = TYPEDEFS_RELATIVE_DIR
typedefs.LUAURC_TEMPLATE = TEMPLATE_RC_FILE

function typedefs.generateConfigDotLuau(languageMode: "strict" | "nonstrict"): string
	local luauConfig = generateLuauConfig(languageMode)
	local luteConfig = generateLuteConfig()

	local configDotLuau = "return " .. tbl({ kv("lute", luteConfig), kv("luau", luauConfig) }, 0)
	return configDotLuau
end

return table.freeze(typedefs)
