local types = require("./e2eCases/types")

return {
	libraryMigration = require("./e2eCases/libraryMigration"),
	apiSurfaceChange = require("./e2eCases/apiSurfaceChange"),
	roactToReact = require("./e2eCases/roactToReact"),
} :: { [string]: types.e2e }
