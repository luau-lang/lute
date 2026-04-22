return [==[
_lute_discover_scripts() {
    local dir="$PWD"
    local seen=()
    local builtins=" run check compile setup lint test transform doc pkg new completion "
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.lute" ]]; then
            for f in "$dir/.lute"/*.luau "$dir/.lute"/*.lua; do
                [[ -f "$f" ]] || continue
                local name
                name=$(basename "$f")
                name="${name%.*}"
                if [[ ! " ${seen[*]} " =~ " $name " ]] && [[ "$builtins" != *" $name "* ]]; then
                    echo "$name"
                    seen+=("$name")
                fi
            done
            for d in "$dir/.lute"/*/; do
                [[ -d "$d" ]] || continue
                if [[ -f "$d/init.luau" || -f "$d/init.lua" ]]; then
                    local name
                    name=$(basename "$d")
                    if [[ ! " ${seen[*]} " =~ " $name " ]] && [[ "$builtins" != *" $name "* ]]; then
                        echo "$name"
                        seen+=("$name")
                    fi
                fi
            done
        fi
        dir=$(dirname "$dir")
    done
}

_lute_luau_files() {
    compgen -f -X '!*.luau' -- "$1"
    compgen -f -X '!*.lua' -- "$1"
    compgen -d -- "$1"
}

_lute_completion() {
    local cur prev words cword

    if type _init_completion &>/dev/null; then
        _init_completion || return
    else
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    fi

    # Identify the subcommand (first non-flag argument after 'lute')
    local subcommand=""
    local i
    for ((i = 1; i < cword; i++)); do
        case "${words[i]}" in
            -*) continue ;;
            *)
                subcommand="${words[i]}"
                break
                ;;
        esac
    done

    # Top-level completion: commands + .lute scripts + luau/lua files
    if [[ -z "$subcommand" ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "-h --help --version" -- "$cur"))
        else
            local commands="run check compile setup lint test transform doc pkg new completion"
            local lute_scripts
            lute_scripts=$(_lute_discover_scripts)
            COMPREPLY=($(compgen -W "$commands $lute_scripts" -- "$cur"))
            COMPREPLY+=($(_lute_luau_files "$cur"))
        fi
        return
    fi

    # Per-subcommand flag/option completion
    case "$subcommand" in
        run)
            case "$prev" in
                --profile-output)
                    COMPREPLY=($(compgen -f -- "$cur"))
                    return ;;
                --frequency)
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--profile --profile-output --frequency -h --help" -- "$cur"))
            else
                local lute_scripts
                lute_scripts=$(_lute_discover_scripts)
                COMPREPLY=($(compgen -W "$lute_scripts" -- "$cur"))
                COMPREPLY+=($(_lute_luau_files "$cur"))
            fi
            ;;
        check)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help" -- "$cur"))
            else
                COMPREPLY=($(_lute_luau_files "$cur"))
            fi
            ;;
        compile)
            case "$prev" in
                --output)
                    COMPREPLY=($(compgen -f -- "$cur"))
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--output --bundle-stats --show-require-graph -h --help" -- "$cur"))
            else
                COMPREPLY=($(_lute_luau_files "$cur"))
            fi
            ;;
        setup)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "--with-luaurc" -- "$cur"))
            fi
            ;;
        lint)
            case "$prev" in
                --rules|-r|--config|-c)
                    COMPREPLY=($(compgen -f -- "$cur"))
                    return ;;
                --string-input|-s)
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help -v --verbose -r --rules -c --config -j --json -s --string-input --auto-fix --no-default-lints" -- "$cur"))
            else
                COMPREPLY=($(_lute_luau_files "$cur"))
            fi
            ;;
        test)
            case "$prev" in
                --suite|-s|--case|-c)
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help --list -s --suite -c --case -i --interactive -u --update -v --verbose" -- "$cur"))
            else
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        transform)
            case "$prev" in
                --output|-o)
                    COMPREPLY=($(compgen -f -- "$cur"))
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help --dry-run -o --output" -- "$cur"))
            else
                COMPREPLY=($(_lute_luau_files "$cur"))
            fi
            ;;
        doc)
            case "$prev" in
                --output|-o)
                    COMPREPLY=($(compgen -d -- "$cur"))
                    return ;;
            esac
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help -o --output" -- "$cur"))
            else
                COMPREPLY=($(compgen -d -- "$cur"))
            fi
            ;;
        pkg)
            local pkg_sub="" seen_pkg=0 j
            for ((j = 1; j < cword; j++)); do
                [[ "${words[j]}" == -* ]] && continue
                if (( seen_pkg )); then
                    pkg_sub="${words[j]}"
                    break
                fi
                seen_pkg=1
            done

            if [[ -z "$pkg_sub" ]]; then
                COMPREPLY=($(compgen -W "run install auth" -- "$cur"))
            elif [[ "$pkg_sub" == "auth" ]]; then
                case "$prev" in
                    --token|--domain) return ;;
                esac
                if [[ "$cur" == -* ]]; then
                    COMPREPLY=($(compgen -W "--token --domain" -- "$cur"))
                fi
            fi
            ;;
        new)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "-h --help" -- "$cur"))
            fi
            ;;
        completion)
            COMPREPLY=($(compgen -W "bash fish zsh" -- "$cur"))
            ;;
        *)
            # Unknown subcommand (likely a .lute script) -- default file completion
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
    esac
}

complete -F _lute_completion lute
]==]
