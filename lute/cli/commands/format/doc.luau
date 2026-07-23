export type LineKind = "normal" | "soft" | "hard"

export type Doc =
	| { read tag: "text", read text: string }
	| { read tag: "concat", read parts: { Doc } }
	| { read tag: "indent", read doc: Doc }
	| { read tag: "line", read kind: LineKind }
	| { read tag: "lineSuffix", read doc: Doc }
	| { read tag: "group", read doc: Doc, shouldBreak: boolean }
	| { read tag: "nil" }

local Doc = {}

Doc.nothing = table.freeze({ tag = "nil" :: "nil" }) :: Doc
Doc.line = table.freeze({ tag = "line" :: "line", kind = "normal" :: LineKind }) :: Doc
Doc.softline = table.freeze({ tag = "line" :: "line", kind = "soft" :: LineKind }) :: Doc
Doc.hardline = table.freeze({ tag = "line" :: "line", kind = "hard" :: LineKind }) :: Doc

function Doc.text(s: string): Doc
	return table.freeze({ tag = "text" :: "text", text = s })
end

function Doc.indent(doc: Doc): Doc
	return table.freeze({ tag = "indent" :: "indent", doc = doc })
end

function Doc.lineSuffix(doc: Doc | string): Doc
	local d = if typeof(doc) == "string" then Doc.text(doc) else doc
	return table.freeze({ tag = "lineSuffix" :: "lineSuffix", doc = d })
end

function Doc.group(doc: Doc, opts: { shouldBreak: boolean? }?): Doc
	return {
		tag = "group" :: "group",
		doc = doc,
		shouldBreak = if opts and opts.shouldBreak then true else false,
	}
end

function Doc.concat(parts: { Doc }, sep: Doc?): Doc
	if sep == nil then
		return table.freeze({ tag = "concat" :: "concat", parts = parts })
	end
	local out: { Doc } = {}
	for i, part in parts do
		if i > 1 then
			table.insert(out, sep)
		end
		table.insert(out, part)
	end
	return table.freeze({ tag = "concat" :: "concat", parts = out })
end

return Doc
