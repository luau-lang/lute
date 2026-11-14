-- lute-lint-global-ignore(unused_variable)
function foo()
    return 1,2,3
end

-- const single export
export const x = 4

-- const multi export
export const a,b,c = foo()
