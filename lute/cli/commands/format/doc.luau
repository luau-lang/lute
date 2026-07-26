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

local function shouldPropogateBreak(node: Doc): boolean
	if typeof(node) == "string" then
		return false
	elseif node.tag == "newline" then
		return true
	elseif node.tag == "concat" then
		for _, part in node.parts do
			if shouldPropogateBreak(part) then
				return true
			end
		end
		return false
	elseif node.tag == "indent" then
		return shouldPropogateBreak(node.contents)
	elseif node.tag == "group" then
		return node.shouldBreak
	elseif node.tag == "choice" then
		return shouldPropogateBreak(node.flat)
	elseif node.tag == "suffix" then
		return false
	else
		error(`unknown node type: {node.tag}`)
	end
end

local function text(text: string): Doc
	return text
end

local none = text("")

--- Prints `contents` as a flat group if it fits, otherwise as a broken group.
--- `shouldBreak` forces the group to break.
local function group(contents: Doc, options: { read shouldBreak: boolean? }?): Doc
	local forced = options ~= nil and options.shouldBreak == true
	return table.freeze({
		tag = "group" :: "group",
		contents = contents,
		shouldBreak = forced or shouldPropogateBreak(contents),
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
local function choice(options: { read flat: Doc?, read broken: Doc? }): Doc
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
	softline = choice({ broken = newline, flat = none }),
	softspace = choice({ broken = newline, flat = text(" ") }),
})
