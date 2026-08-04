local b: (n: number) -> number

local function a(n: number): number
    return n + b(n);
end

b = function(n: number): number
    if n == 0 then
        return 0
    end
    return n +  a(n-1)
end

a(3)
