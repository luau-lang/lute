---
order: 8
---

# Self

Manage a Lute installation stored in `~/.lute`.

## Install

Copy the running Lute executable to `~/.lute/bin`, add that directory to `PATH`:

```bash
lute self install
```

Use `--no-modify-path` to leave shell configuration unchanged or `--force` to replace an existing installation without prompting.

## Update

Update the installed host executable to the latest stable release:

```bash
lute self update
```

Install a specific release with `--version`. Both `1.0.1` and `v1.0.1` are accepted:

```bash
lute self update --version 1.0.1
```

Specify the desired nightly version explicitly if desired:

```bash
lute self update --version 1.0.1-nightly.20260710
```

## Uninstall

Remove the host executable and its managed `PATH` entry:

```bash
lute self uninstall
```
