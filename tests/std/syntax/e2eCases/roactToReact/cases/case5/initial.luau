local Roact = require(PackagesRoot.Roact)

local instance = Roact.mount(element, nil, "Root")
Roact.unmount(instance)
