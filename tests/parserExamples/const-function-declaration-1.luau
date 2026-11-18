-- lute-lint-global-ignore(unused_variable)
const function f()
	return 42
end

@native
const      function g<T>(value: T): T
	const function inner()
		return value
	end
	return inner()
end
