local ReactRoblox = require(PackagesRoot.ReactRoblox)

local container = Instance.new("Folder")
local root = ReactRoblox.createRoot(Instance.new("Folder"))
local actualParent = container
local actualKey = "ReactRoot"
ReactRoblox.act(function()
	root:render(ReactRoblox.createPortal({ [actualKey] = arbitraryElement } :: any, actualParent))
end)
local instance = { root = root, parent = actualParent, key = actualKey }
ReactRoblox.act(function()
	instance.root:render(ReactRoblox.createPortal({ [instance.key] = otherElement } :: any, instance.parent))
end)
