local Roact = require(PackagesRoot.Roact)

return Roact.createElement(Roact.Portal, {
	target = arbitraryRoot,
}, children)
