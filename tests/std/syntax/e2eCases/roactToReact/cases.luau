return {
	-- createFragment case
	{
		initial = [[
	local Roact = require(PackagesRoot.Roact)

	return Roact.createFragment(arbitraryElement)
	]],
		expected = [[
	local React = require(PackagesRoot.React)

	return React.createElement(React.Fragment, nil, arbitraryElement)
	]],
	},

	-- one child case
	{
		initial = [[
	local Roact = require(PackagesRoot.Roact)

	return Roact.createElement(arbitraryElement, nil, Roact.oneChild(otherArbitraryElement))
	]],
		expected = [[
	local React = require(PackagesRoot.React)

	return React.createElement(arbitraryElement, nil,
	if not otherArbitraryElement or not select(2, next(otherArbitraryElement)) or next(otherArbitraryElement, table.pack(select(1, next(otherArbitraryElement) :: string))[1])
	    then nil
	else React.Children.only(select(2, next(otherArbitraryElement) :: any)))
	]],
	},

	-- 	-- portal case
	{
		initial = [[
	local Roact = require(PackagesRoot.Roact)

	return Roact.createElement(Roact.Portal, {
	    target = arbitraryRoot,
	}, children)
	]],
		expected = [[
	local ReactRoblox = require(PackagesRoot.ReactRoblox)

	return ReactRoblox.createPortal(children, arbitraryRoot)
	]],
	},

	-- Roact.Ref / Roact.Children case
	{
		initial = [[
	local Roact = require(PackagesRoot.Roact)

	return Roact.createElement(abitraryElement, {
	    [Roact.Ref] = arbitraryRef,
	    [Roact.Children] = arbitraryChildren,
	})
	]],
		expected = [[
	local React = require(PackagesRoot.React)

	return React.createElement(abitraryElement, {
	    ref = arbitraryRef,
	    children = arbitraryChildren,
	})
	]],
	},

	-- mount, unmout, update case
	{
		initial = [[
    local Roact = require(PackagesRoot.Roact)    

    local instance = Roact.mount(element, nil, "Root")
    Roact.unmount(instance)

    ]],
		expected = [[
    local ReactRoblox = require(PackagesRoot.ReactRoblox)

    local root = ReactRoblox.createRoot(Instance.new("Folder"))
    local actualParent = Instance.new("Folder")
    local actualKey = "Root"
    ReactRoblox.act(function()
        root:render(ReactRoblox.createPortal({ [actualKey] = element } :: any, actualParent))
    end)
    local instance = { root = root, parent = actualParent, key = actualKey }
    instance.root:unmount()
    ]],
	},
	{
		initial = [[
    local Roact = require(PackagesRoot.Roact)

    local container = Instance.new("Folder")
    local instance = Roact.mount(arbitraryElement, container)
    Roact.update(instance, otherElement)
    ]],
		expected = [[
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
    ]],
	},
}
