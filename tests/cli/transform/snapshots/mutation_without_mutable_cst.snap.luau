local util = require("./util")

-- Without `--mutable-cst` the CST is frozen, so the migration errors and the file is left untouched.
util.printTransform("mutation_without_mutable_cst", "mutation", {})
