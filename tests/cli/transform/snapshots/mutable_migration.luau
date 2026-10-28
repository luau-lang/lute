-- Rewrites `~=` comparisons to `==` by editing the CST in place. Requires `lute transform --mutable-cst`.
local transformTypes = require("@transform")

return function(ctx: transformTypes.MutableContext)
	for _, stat in ctx.parseresult.root.statements do
		if stat.tag == "local" then
			for _, value in stat.values do
				if value.tag == "binary" and value.operator.text == "~=" then
					value.operator.text = "=="
				end
			end
		end
	end

	return {}
end
