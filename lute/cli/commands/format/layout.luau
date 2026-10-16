const doc = require("./doc")

export type Options = {
	read width: number?,
	read indentWidth: number?,
	read enableTabs: boolean?,
}

-- "flat" mode means the group is allowed to print on one line
-- "break" mode means the group must print on multiple lines
type Mode = "flat" | "break"

const layoutLib = {}

function layoutLib.render(root: doc.Doc, options: Options?): string
	-- const width = if options and options.width then options.width else 120
	-- const indentWidth = if options and options.indentWidth then options.indentWidth else 4
	-- const enableTabs = if options and options.enableTabs ~= nil then options.enableTabs else true
	const out: { string } = {}
	return table.concat(out)
end

return table.freeze(layoutLib)
