# no-vibe path helpers, sourced by the write guards.

# Normalize Windows-style drive paths (`C:/foo`, `c:\foo`) to MSYS form
# (`/c/foo`) so prefix comparisons stay consistent on Git Bash. MSYS converts
# paths when crossing the bash/native-binary boundary, so one hook run can
# see `C:/...` from the host and `/c/...` inside a command.
normalize_path() {
    local p="$1"
    # Backslashes are separators only on Windows. Elsewhere `\` is a legal
    # filename character, and translating it would let `.no-vibe/a\b/../../x`
    # pass for a path inside .no-vibe/.
    case "${OSTYPE:-}" in
        msys*|cygwin*|win32*) p=$(printf '%s' "$p" | tr '\\' '/') ;;
    esac
    # `C:/foo` or `c:/foo` → `/c/foo` (portable, no bash 4 lowercase op).
    case "$p" in
        [A-Za-z]:/*)
            local drive
            drive=$(printf '%s' "${p%%:*}" | tr '[:upper:]' '[:lower:]')
            p="/$drive${p#?:}"
            ;;
        [A-Za-z]:)
            local drive
            drive=$(printf '%s' "${p%%:*}" | tr '[:upper:]' '[:lower:]')
            p="/$drive"
            ;;
    esac
    printf '%s' "$p"
}

# resolve_path ABS: prints the absolute path ABS names, with symlinks resolved
# and `.` and `..` removed, whether or not it exists. The deepest existing
# directory is resolved with `cd -P`, which every bash has, and the rest is
# applied lexically, so it needs no GNU-only flags. Prints nothing, so callers
# refuse, for a relative path, an overlong path, or a path that crosses a
# symlink or uses a file as a directory after that point: where a write
# through it lands is not known.
resolve_path() {
    local dir="$1" rest="" part slashes
    case "$dir" in
        /*) ;;
        *) return 0 ;;
    esac
    # Bounded input keeps every check below under PATH_MAX and the loops
    # short. Real targets are far smaller.
    slashes=${dir//[!\/]/}
    [ "${#dir}" -gt 1024 ] && return 0
    [ "${#slashes}" -gt 128 ] && return 0
    # `//x` is `/x`, and `pwd -P` would keep the double slash.
    while [ "${dir#//}" != "$dir" ]; do dir="${dir#/}"; done
    while [ "${#dir}" -gt 1 ] && [ "${dir%/}" != "$dir" ]; do dir="${dir%/}"; done
    while [ ! -d "$dir" ]; do
        rest="/${dir##*/}$rest"
        dir="${dir%/*}"
        [ -z "$dir" ] && dir=/
    done
    dir=$(cd -P -- "$dir" 2>/dev/null && pwd -P) || return 0
    rest="${rest#/}"
    while [ -n "$rest" ]; do
        part="${rest%%/*}"
        case "$rest" in
            */*) rest="${rest#*/}" ;;
            *) rest="" ;;
        esac
        case "$part" in
            ""|.) continue ;;
            ..) dir="${dir%/*}"; [ -z "$dir" ] && dir=/; continue ;;
        esac
        if [ "$dir" = / ]; then dir="/$part"; else dir="$dir/$part"; fi
        # A symlink, dangling or not, hides the real target, and so does a
        # file used as a directory: refuse both.
        [ -L "$dir" ] && return 0
        [ -n "$rest" ] && [ -e "$dir" ] && [ ! -d "$dir" ] && return 0
    done
    printf '%s' "$dir"
}
