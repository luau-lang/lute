export type test = { [string]: number }

return function (s: string, n: number): test
    return {
        [s] = n,
    }
end