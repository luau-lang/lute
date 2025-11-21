local Roact = require(PackagesRoot.Roact)

local container = Instance.new("Folder")
local instance = Roact.mount(arbitraryElement, container)
Roact.update(instance, otherElement)
