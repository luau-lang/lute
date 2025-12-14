local net = require("@lute/net")

return {
	check = function()
		local ok, err = pcall(net.serve, nil)
		if ok then
			error("expected net.serve to error on invalid arguments")
		end

		if type(err) == "string" and string.find(err, "not implemented", 1, true) then
			error("expected native @lute/net implementation in child VM, got definitions stub")
		end
	end,
}
