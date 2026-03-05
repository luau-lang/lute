To add a new default lint rule to `lute lint`:
1. Create a module or luau file defining the rule in this folder.
Each violation should report its target as `"https://lute.luau.org/cli/lint/<your rule name>.html"`.
1. Add the name of the rule to the `DEFAULT_RULES` constant in `lint/init.luau`
1. Add tests for the rule in `tests/cli/lint.test.luau`
1. Add documentation for it in `docs/cli/lint`. The doc's title should be the same as your rule's name.

The expected type of a lint rule is specified in `lint/types.luau`. 