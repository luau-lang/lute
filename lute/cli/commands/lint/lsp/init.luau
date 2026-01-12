local pathLib = require("@std/path")
local lintTypes = require("./types")
local lspTypes = require("@self/types")
local tableext = require("@std/tableext")

local lsp = {}

local function severity(sev: lintTypes.severity): number
	if sev == "error" then
		return 1
	elseif sev == "warning" then
		return 2
	elseif sev == "info" then
		return 3
	else
		return 4
	end
end

local function tag(t: lintTypes.tag): number
	if t == "unnecessary" then
		return 1
	else
		return 2
	end
end

function lsp.diagnostic(lint: lintTypes.LintViolation): lspTypes.Diagnostic
	return table.freeze({
		range = table.freeze({
			start = table.freeze({
				line = lint.location.beginline - 1,
				character = lint.location.begincolumn - 1,
			}),
			["end"] = table.freeze({
				line = lint.location.endline - 1,
				character = lint.location.endcolumn - 1,
			}),
		}),
		severity = severity(lint.severity),
		code = lint.lintname,
		source = "lute lint" :: "lute lint", -- LUAUFIX: Errors because this isn't inferred as a singleton
		message = lint.message,
		tags = if lint.tags then table.freeze(tableext.map(lint.tags, tag)) else nil,
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
