--[[
	A `Doc` describes the possible layouts of a fragment of source rather than one
	concrete layout: `group` marks a region to keep on one line if it fits,
	`softline` and `softspace` mark where to break when it does not. The algorithm
	is Wadler's, via Prettier.

	A plain string is a `Doc`, so literal source text needs no wrapper.
]]

export type ConcatDoc = { read tag: "concat", read parts: { read [number]: Doc } }

export type IndentDoc = { read tag: "indent", read contents: Doc }

export type GroupDoc = { read tag: "group", read contents: Doc, read shouldBreak: boolean }

export type IfBreakDoc = { read tag: "ifBreak", read broken: Doc, read flat: Doc }

export type NewlineDoc = { read tag: "newline" }

export type LineSuffixDoc = { read tag: "lineSuffix", read contents: Doc }

export type Doc = string | ConcatDoc | IndentDoc | GroupDoc | IfBreakDoc | NewlineDoc | LineSuffixDoc

local Doc = {}

Doc.none = ""

function Doc.concat(parts: { read [number]: Doc }, separator: Doc?): Doc
	if separator ~= nil then
		local joined: { Doc } = {}
		for index, part in parts do
			if index > 1 then
				table.insert(joined, separator)
			end
			table.insert(joined, part)
		end
		parts = table.freeze(joined)
	end
	return table.freeze({ tag = "concat" :: "concat", parts = parts })
end

--- Indents newlines produced inside `contents` by one level.
function Doc.indent(contents: Doc): Doc
	return table.freeze({ tag = "indent" :: "indent", contents = contents })
end

--- Prints `contents` flat if it fits in the remaining columns, otherwise broken.
--- `shouldBreak` skips the measurement and always breaks.
function Doc.group(contents: Doc, options: { read shouldBreak: boolean? }?): Doc
	return table.freeze({
		tag = "group" :: "group",
		contents = contents,
		shouldBreak = if options ~= nil and options.shouldBreak then true else false,
	})
end

--- Picks a branch according to whether the enclosing group broke, e.g. a trailing comma.
function Doc.ifBreak(broken: Doc, flat: Doc?): Doc
	return table.freeze({
		tag = "ifBreak" :: "ifBreak",
		broken = broken,
		flat = if flat ~= nil then flat else Doc.none,
	})
end

--- Always a newline, and forces every enclosing group to break.
Doc.newline = table.freeze({ tag = "newline" :: "newline" })

--- A newline when its group breaks, otherwise nothing.
Doc.softline = Doc.ifBreak(Doc.newline, Doc.none)

--- A newline when its group breaks, otherwise a space.
Doc.softspace = Doc.ifBreak(Doc.newline, " ")

--- Defers `contents` until just before the next newline, so a trailing line comment cannot swallow the code after its token.
function Doc.lineSuffix(contents: Doc): Doc
	return table.freeze({ tag = "lineSuffix" :: "lineSuffix", contents = contents })
end

return table.freeze(Doc)
