local ReactRoblox = require(PackagesRoot.ReactRoblox)

local root = ReactRoblox.createRoot(Instance.new("Folder"))
local actualParent = Instance.new("Folder")
local actualKey = "Root"
ReactRoblox.act(function()
	root:render(ReactRoblox.createPortal({ [actualKey] = element } :: any, actualParent))
end)
local instance = { root = root, parent = actualParent, key = actualKey }
instance.root:unmount()
