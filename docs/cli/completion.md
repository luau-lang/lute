# completion

Generate shell completion scripts for `lute`, enabling tab-completion for commands, flags, and `.lute` scripts.

```
lute completion <shell> [options]
```

## Supported shells

### - `bash`
### - `fish`
### - `zsh`

## Options

### `-h, --help`

Display this usage message.

## Setup

### Bash

First, ensure that you install `bash-completion` using your package manager.

After, add this to your `~/.bashrc` or `~/.bash_profile`:

```bash
eval "$(lute completion bash)"
```

### Fish

Generate the completion script:

```fish
lute completion fish > ~/.config/fish/completions/lute.fish
```

Alternatively, you can source it directly in `~/.config/fish/config.fish`:

```fish
lute completion fish | source
```

### Zsh

Generate a `_lute` completion script and put it somewhere in your `$fpath`:

```zsh
lute completion zsh > /usr/local/share/zsh/site-functions/_lute
```

Ensure that the following is present in your `~/.zshrc`:

```zsh
autoload -U compinit
compinit -i
```

Alternatively, you can source the completions directly in your `~/.zshrc`:

```zsh
eval "$(lute completion zsh)"
```
