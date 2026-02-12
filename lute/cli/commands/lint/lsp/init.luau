local lintTypes = require("./types")
local lspTypes = require("@self/types")
local pathLib = require("@std/path")
local syntax = require("@std/syntax")
local tableext = require("@std/tableext")

local lsp = {}

local function severity(sev: lintTypes.severity): number
	if sev == "error" then
		return 0
	elseif sev == "warning" then
		return 1
	elseif sev == "info" then
		return 2
	else
		return 3
	end
end

local function tag(t: lintTypes.tag): number
	if t == "unnecessary" then
		return 1
	else
		return 2
	end
end

local function getRange(location: syntax.span): lspTypes.Range
	return table.freeze({
		start = table.freeze({
			line = location.beginline - 1,
			character = location.begincolumn - 1,
		}),
		["end"] = table.freeze({
			line = location.endline - 1,
			character = location.endcolumn - 1,
		}),
	})
end

function lsp.diagnostic(lint: lintTypes.LintViolation): lspTypes.Diagnostic
	return table.freeze({
		range = getRange(lint.location),
		severity = severity(lint.severity),
		code = lint.lintname,
		codeDescription = lint.target,
		source = "lute lint" :: "lute lint", -- LUAUFIX: Annotation needed, otherwise this errors because string isn't inferred as a singleton
		message = lint.message,
		tags = if lint.tags then table.freeze(tableext.map(lint.tags, tag)) else nil,
		suggestedfix = if lint.suggestedfix
			then table.freeze({
				fix = lint.suggestedfix.fix,
				range = getRange(lint.suggestedfix.location or lint.location),
			})
			else nil,
	})
end

local function workspaceDocumentDiagnosticReport(
	path: pathLib.path,
	violations: { lintTypes.LintViolation }
): lspTypes.WorkspaceDocumentDiagnosticReport
	local report = { items = {}, uri = pathLib.format(path) }
	for _, violation in violations do
		table.insert(report.items, lsp.diagnostic(violation))
	end
	return table.freeze(report)
end

function lsp.workspaceDiagnosticReport(
	violations: { [pathLib.path]: { lintTypes.LintViolation } }
): lspTypes.WorkspaceDiagnosticReport
	local report = {
		items = {},
	}

	for path, pathViolations in violations do
		table.insert(report.items, workspaceDocumentDiagnosticReport(path, pathViolations))
	end

	return table.freeze(report)
end

return table.freeze(lsp)
