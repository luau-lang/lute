--[[
	A "Doc" is an IR for a partially formatted source tree. It encodes the possible
	layout decisions that can be made to "groups" of other Docs, which concretely
	map to function calls, table literals, and other grouping constructs in the AST.
]]

export type Doc = TextDoc | GroupDoc | IndentDoc | SuffixDoc | ConcatDoc | ChoiceDoc | NewlineDoc

const docLib = {}

export type TextDoc = string

function docLib.text(text: string): TextDoc
	return text
end

docLib.none = docLib.text("")

export type GroupDoc = { read tag: "group", read contents: Doc, read shouldBreak: boolean }

--- Prints `contents` as a flat group if it fits, otherwise as a broken group.
--- `shouldBreak` forces the group to break.
function docLib.group(contents: Doc, options: { read shouldBreak: boolean? }?): GroupDoc
	return table.freeze({
		tag = "group" :: "group",
		contents = contents,
		shouldBreak = options ~= nil and options.shouldBreak == true,
	})
end

export type IndentDoc = { read tag: "indent", read contents: Doc }

--- Indents newlines produced inside `contents` by one level.
function docLib.indent(contents: Doc): IndentDoc
	return table.freeze({ tag = "indent" :: "indent", contents = contents })
end

export type SuffixDoc = { read tag: "suffix", read contents: Doc }

--- Defers `contents` until just before the next newline, so a trailing line comment cannot swallow the code after its token.
function docLib.suffix(contents: Doc): SuffixDoc
	return table.freeze({ tag = "suffix" :: "suffix", contents = contents })
end

export type ConcatDoc = { read tag: "concat", read parts: { read [number]: Doc } }

--- Joins `parts` with an optional `separator` between each part, similar to `table.concat`.
function docLib.concat(parts: { read [number]: Doc }, separator: Doc?): ConcatDoc
	if separator ~= nil then
		const joined: { Doc } = {}
		for index, part in parts do
			if index > 1 then
				table.insert(joined, separator)
			end
			table.insert(joined, part)
		end
		parts = table.freeze(joined)
	else
		parts = table.freeze(table.clone(parts))
	end
	return table.freeze({ tag = "concat" :: "concat", parts = parts })
end

export type ChoiceDoc = { read tag: "choice", read broken: Doc, read flat: Doc }

--- Picks a branch according to whether the enclosing group is flat or broken.
function docLib.choice(options: { read flat: Doc?, read broken: Doc? }): ChoiceDoc
	return table.freeze({
		tag = "choice" :: "choice",
		flat = options.flat or docLib.none,
		broken = options.broken or docLib.none,
	})
end

export type NewlineDoc = { read tag: "newline" }

--- Always a newline, and forces every enclosing group to break.
docLib.newline = table.freeze({ tag = "newline" :: "newline" })

--- Nothing when the enclosing group is flat, a newline when it is broken.
docLib.softline = docLib.choice({ broken = docLib.newline, flat = docLib.none })

--- A space when the enclosing group is flat, a newline when it is broken.
docLib.softspace = docLib.choice({ broken = docLib.newline, flat = docLib.text(" ") })

return table.freeze(docLib)
