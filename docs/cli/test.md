# test

Run tests discovered in .test.luau and .spec.luau files (defaults to looking for files in a tests/ directory).

## Usage

```bash
lute test [OPTIONS] [PATHS...]
```

## Options

### `-h, --help`

Show this help message

### `--list`

List all discovered test cases without running them

### `-s, --suite SUITE`

Run only tests in the specified suite

### `-c, --case CASE`

Run only test cases matching the specified name

## Arguments

Directories or files to search for tests (default: ./tests)

## Examples

Run all tests in ./tests:

```bash
lute test
```

List all test cases:

```bash
lute test --list
```

Run all tests in MyTestSuite:

```bash
lute test -s MyTestSuite
```

Run specific test in suite:

```bash
lute test --suite MyTestSuite --case mytest
```

Run all test cases named "some case":

```bash
lute test --case "some case"
```

List tests that were discovered in my/other/testdir:

```bash
lute test --list my/other/testdir
```