--[[
	A `Doc` describes the possible layouts of a fragment of source rather than one
	concrete layout: `group` marks a region to keep on one line if it fits,
	`softline` and `softspace` mark where to break when it does not.
]]

export type TextDoc = string

export type NewlineDoc = { read tag: "newline" }

export type ConcatDoc = { read tag: "concat", read parts: { read [number]: Doc } }

export type IndentDoc = { read tag: "indent", read contents: Doc }

export type SuffixDoc = { read tag: "suffix", read contents: Doc }

export type GroupDoc = { read tag: "group", read contents: Doc, read shouldBreak: boolean }

export type ChoiceDoc = { read tag: "choice", read broken: Doc, read flat: Doc }

export type Doc = TextDoc | ConcatDoc | IndentDoc | GroupDoc | ChoiceDoc | NewlineDoc | SuffixDoc

local function text(text: string): Doc
	return text
end

local none = text("")

--- Prints `contents` flat if it fits in the remaining columns, otherwise broken.
--- `shouldBreak` skips the measurement and always breaks.
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

--- Picks a branch according to whether the enclosing group broke, e.g. a trailing comma.
local function choice(broken: Doc, flat: Doc?): Doc
	return table.freeze({
		tag = "choice" :: "choice",
		broken = broken,
		flat = if flat ~= nil then flat else none,
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
