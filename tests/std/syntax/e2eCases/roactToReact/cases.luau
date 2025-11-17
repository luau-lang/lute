return {
    -- want a test case for each migrated function;
    -- include requires in each test case

    --[[
        ["createFragment"] = convertCreateFragment, -> React.createElement(React.Fragment, nil, currentArg)

        ["oneChild"] = convertOneChild, ->
        if not currentArg or not select(2, next(currentArg)) or next(currentArg, table.pack(select(1, next(currentArg) :: string))[1])
				then nil
			else React.Children.only(select(2, next(currentArg)) :: any)
        
        ["Roact.Ref"] = convertRoactRef, -> ref
        ["Roact.Children"] = convertRoactChildren, -> children

        ["Portal"] = convertRoactPortal,

        ["mount"] = convertRoactMount,
        ["update"] = convertRoactUpdate,
        ["unmount"] = convertRoactUnmount,
    ]]

	[ [[
local Roact = require(PackagesRoot.Roact)

return Roact.createFragment(abitraryElement)
]] ] = [[
local React = require(PackagesRoot.React)

return React.createElement(React.Fragment, nil, arbitraryElement)
]],
	[ [[
local Roact = require(PackagesRoot.Roact)

return Roact.createElement(arbiraryElement, nil, Roact.oneChild(otherArbitraryElement))
]] ] = [[
local React = require(PackagesRoot.React)

return React.createElement(arbiraryElement, nil, if not otherArbitraryElement or not eslect(2, ()))
]],
	[ [[]] ] = [[]],
}
