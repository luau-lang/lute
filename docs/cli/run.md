# run

Run a Luau script. Can be omitted if you just pass the name of the script
to Lute. `lute run` also comes with a sampling profiler, that outputs json traces that can be
viewed at ui.perfetto.dev. The profiler currently only works with single threaded code.

## Usage

```bash
lute run <script.luau> [args...]
```
is equivalent to:

```bash
lute <script.luau> [args...]
```

```bash
lute --profile [--profile-output somefile] [--frequency <number> ] <script.luau> [args...]
```
will profile the execution of `script.luau` at the provided frequency, outputting the trace to a file called
somefile.


## Options

### `-h, --help`

Display this usage message.

### `--profile`

Enable profiling for the script being passed to `lute run`. Default sampling frequency is
10000Hz, and default profile name is <datetime>_<filename>.json.

### `--profile-output <filename>`

Sets the desired filename for the profile trace dump;

### `--frequency <number in Hz>`

Sets the frequency at which the profiler will sample the callstack.


