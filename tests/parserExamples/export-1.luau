-- lute-lint-global-ignore(unused_variable)
function foo()
    return 1,2,3
end

-- single exports
export local v1 = 4
-- multi exports
export local v2,v3,v4 = foo()

-- single export no init
export local v7

-- multi exports no init
export local v5,v6
