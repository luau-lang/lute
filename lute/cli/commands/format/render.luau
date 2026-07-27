local doc = require("./doc")

export type Options = {
	read width: number?,
	read indentWidth: number?,
	read enableTabs: boolean?,
}

-- "flat" mode means the group is allowed to print on one line
-- "break" mode means the group must print on multiple lines
type Mode = "flat" | "break"

--- A unit of pending work: a doc plus the indent level and layout mode it
--- inherited from its enclosing group.
type Step = { read level: number, read mode: Mode, read doc: doc.Doc }

local function makeStep(level: number, mode: Mode, node: doc.Doc): Step
	return table.freeze({ level = level, mode = mode, doc = node })
end

local function render(root: doc.Doc, options: Options?): string
	local width = if options and options.width then options.width else 80
	local indentWidth = if options and options.indentWidth then options.indentWidth else 4
	local enableTabs = if options and options.enableTabs ~= nil then options.enableTabs else true

	local column = 0
	local out: { string } = {}

	return table.concat(out)
end

return table.freeze({
	render = render,
})
