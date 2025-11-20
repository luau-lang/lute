local React = require(PackagesRoot.React)

return React.createElement(
	arbitraryElement,
	nil,
	if not otherArbitraryElement
			or not select(2, next(otherArbitraryElement))
			or next(otherArbitraryElement, table.pack(select(1, next(otherArbitraryElement) :: string))[1])
		then nil
		else React.Children.only(select(2, next(otherArbitraryElement) :: any))
)
