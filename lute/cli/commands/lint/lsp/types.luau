export type Diagnostic = {
	read range: Range, -- zero-based
	read severity: number, -- 1: Error, 2: Warning, 3: Information, 4: Hint
	read code: string, -- lint name
	read codeDescription: string?, -- optional property to describe the violation; can also be
	read source: "lute lint",
	read message: string,
	read tags: { number }?, -- 1: Unnecessary, 2: Deprecated
	read suggestedfix: {
		read fix: string,
		read range: Range,
	}?,
}

export type Range = {
	read start: { read line: number, read character: number },
	read ["end"]: { read line: number, read character: number },
}

export type WorkspaceDocumentDiagnosticReport = {
	read items: { Diagnostic },
	read uri: string, -- Note: Any lsp consumers will need to ensure this is a proper file URI. For now, we just use the file path.
}

export type WorkspaceDiagnosticReport = {
	read items: { WorkspaceDocumentDiagnosticReport },
}

return table.freeze({})
