-- strict

local assert = {}
-- todo: we should add some more assertions for diffing tables!
function assert.eq<T>(lhs: T, rhs: T)
	if lhs ~= rhs then
		error({ msg = `{lhs} ~= {rhs}` })
	end
end

function assert.neq<T>(lhs: T, rhs: T)
	if lhs == rhs then
		error({ msg = `{lhs} == {rhs}` })
	end
end

export type Asserts = typeof(assert)

table.freeze(assert)
return assert
