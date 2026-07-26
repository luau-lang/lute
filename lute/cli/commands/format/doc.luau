--[[
	A "Doc" is an IR for a partially formatted source tree. It encodes the possible
	layout decisions that can be made to "groups" of other Docs, which concretely
	map to function calls, table literals, and other grouping constructs in the AST.
]]

export type TextDoc = string

export type NewlineDoc = { read tag: "newline" }

export type ConcatDoc = { read tag: "concat", read parts: { read [number]: Doc } }

export type IndentDoc = { read tag: "indent", read contents: Doc }

export type SuffixDoc = { read tag: "suffix", read contents: Doc }

export type GroupDoc = { read tag: "group", read contents: Doc, read shouldBreak: boolean }

export type ChoiceDoc = { read tag: "choice", read broken: Doc, read flat: Doc }

export type Doc = TextDoc | NewlineDoc | ConcatDoc | IndentDoc | SuffixDoc | GroupDoc | ChoiceDoc

local function text(text: string): Doc
	return text
end

local none = text("")

--- Prints `contents` flat if it fits in the remaining columns, otherwise broken.
--- `shouldBreak` skips the fitness measurement and always breaks.
local function group(contents: Doc, options: { read shouldBreak: boolean? }?): Doc
	return table.freeze({
		tag = "group" :: "group",
		contents = contents,
		shouldBreak = if options ~= nil and options.shouldBreak then true else false,
	})
end

--- Indents newlines produced inside `contents` by one level.
local function indent(contents: Doc): Doc
	return table.freeze({ tag = "indent" :: "indent", contents = contents })
end

--- Defers `contents` until just before the next newline, so a trailing line comment cannot swallow the code after its token.
local function suffix(contents: Doc): Doc
	return table.freeze({ tag = "suffix" :: "suffix", contents = contents })
end

-- Joins `parts` with an optional `separator`
local function concat(parts: { read [number]: Doc }, separator: Doc?): Doc
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

--- Picks a branch according to whether the enclosing group is flat or broken.
local function choice(options: { read flat: Doc?, read broken: Doc?}): Doc
	return table.freeze({
		tag = "choice" :: "choice",
		flat = options.flat or none,
		broken = options.broken or none,
	})
end

--- Always a newline, and forces every enclosing group to break.
local newline = table.freeze({ tag = "newline" :: "newline" })

return table.freeze({
	none = none,
	text = text,
	group = group,
	indent = indent,
	suffix = suffix,
	concat = concat,
	choice = choice,
	newline = newline,
	softline = choice(newline, none),
	softspace = choice(newline, text(" ")),
})
