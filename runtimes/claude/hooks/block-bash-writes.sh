#!/usr/bin/env bash
# no-vibe PreToolUse hook for Bash: blocks shell writes outside the
# safe-target allowlist when .no-vibe/active exists.
#
# Pattern definitions live in shared/guard/patterns.json. The parsing
# logic lives here (Bash regex / token walking can't be expressed as
# raw JSON). When changing what's blocked, edit patterns.json + this
# file together.
#
# Reads JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

normalize_path() {
    local p="$1"
    p=$(printf '%s' "$p" | tr '\\' '/')
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

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
cwd=$(normalize_path "$cwd")

if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[ "$tool_name" = "Bash" ] || exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

deny() {
    cat >&2 <<EOF
no-vibe mode is active. Refusing Bash command that writes outside
the safe-target allowlist:

  $cmd

Reason: $1

Safe targets: \`.no-vibe/**\`, \`\$HOME/.no-vibe/**\`, \`/tmp/**\`,
\`/var/tmp/**\`, \`/dev/{null,stdout,stderr,tty,fd/*}\`.
Variable / command-substitution destinations fail closed.

Show the code in chat; let the user run it. To exit: \`/no-vibe off\`.
EOF
    exit 2
}

home_dir=$(normalize_path "${HOME:-/root}")
if command -v realpath >/dev/null 2>&1; then
    scratch_root=$(normalize_path "$(realpath -m "$cwd/.no-vibe")")
    home_scratch_root=$(normalize_path "$(realpath -m "$home_dir/.no-vibe")")
else
    scratch_root="$cwd/.no-vibe"
    home_scratch_root="$home_dir/.no-vibe"
fi

is_safe_path() {
    local p="$1"
    case "$p" in
        \"*\") p=${p#\"}; p=${p%\"} ;;
        \'*\') p=${p#\'}; p=${p%\'} ;;
    esac
    [ -z "$p" ] && return 1
    case "$p" in
        *\$\(*|*\`*|*\$\{*|\$*) return 1 ;;
    esac
    case "$p" in
        /dev/null|/dev/stdout|/dev/stderr|/dev/fd/*|/dev/tty) return 0 ;;
        /tmp|/tmp/*|/var/tmp|/var/tmp/*) return 0 ;;
    esac
    p=$(normalize_path "$p")
    local abs
    case "$p" in
        /*) abs="$p" ;;
        *)  abs="$cwd/$p" ;;
    esac
    if command -v realpath >/dev/null 2>&1; then
        abs=$(realpath -m "$abs" 2>/dev/null || echo "$abs")
    fi
    abs=$(normalize_path "$abs")
    case "$abs" in
        "$scratch_root"|"$scratch_root"/*) return 0 ;;
        "$home_scratch_root"|"$home_scratch_root"/*) return 0 ;;
        /tmp|/tmp/*|/var/tmp|/var/tmp/*) return 0 ;;
    esac
    return 1
}

clean=$(printf '%s' "$cmd" | sed -E 's/[0-9]+>&[0-9]+//g; s/[0-9]+<&[0-9]+//g')

# 1. Output redirection.
while IFS= read -r match; do
    [ -z "$match" ] && continue
    target=$(printf '%s' "$match" | sed -E 's/^(&>>?|>>?)[[:space:]]*//')
    if ! is_safe_path "$target"; then
        deny "redirection writes to '$target'"
    fi
done < <(printf '%s' "$clean" | grep -oE '(&>>?|>>?)[[:space:]]*[^[:space:]|&;<>()]+' || true)

# 2. tee.
if printf '%s' "$clean" | grep -qE '(^|[[:space:]|;&(])tee([[:space:]]|$)'; then
    tee_args=$(printf '%s' "$clean" | sed -E 's/.*([[:space:]|;&(])tee[[:space:]]+/ /; t; s/^tee[[:space:]]+//')
    for tok in $tee_args; do
        case "$tok" in
            -*) continue ;;
            \||\&\&|\|\||\;|\)|\() break ;;
            *)
                if ! is_safe_path "$tok"; then
                    deny "tee writes to '$tok'"
                fi
                ;;
        esac
    done
fi

# 3. sed -i / --in-place.
if printf '%s' "$clean" | grep -qE '(^|[[:space:]|;&(])sed[[:space:]]+([^|;&]*[[:space:]])?(-[a-zA-Z]*i\b|--in-place)'; then
    after_sed=$(printf '%s' "$clean" | sed -E 's/.*([[:space:]|;&(])sed[[:space:]]+/ /; t; s/^sed[[:space:]]+//')
    skip_next=0
    saw_script=0
    for tok in $after_sed; do
        if [ "$skip_next" = "1" ]; then skip_next=0; continue; fi
        case "$tok" in
            -e|-f) skip_next=1; continue ;;
            -i|--in-place|-i*|--in-place=*) continue ;;
            -*) continue ;;
            \||\&\&|\|\||\;|\)|\() break ;;
            *)
                if [ "$saw_script" = "0" ]; then saw_script=1; continue; fi
                if ! is_safe_path "$tok"; then
                    deny "sed -i mutates '$tok'"
                fi
                ;;
        esac
    done
fi

# 4. cp / mv / install.
for cmdname in cp mv install; do
    if printf '%s' "$clean" | grep -qE "(^|[[:space:]|;&(])${cmdname}([[:space:]]|$)"; then
        seg=$(printf '%s' "$clean" | sed -E "s/.*([[:space:]|;&(])${cmdname}[[:space:]]+/ /; t; s/^${cmdname}[[:space:]]+//" | sed -E 's/[|;&].*//')
        last=""
        for tok in $seg; do
            case "$tok" in
                -*) continue ;;
                *) last="$tok" ;;
            esac
        done
        if [ -n "$last" ] && ! is_safe_path "$last"; then
            deny "$cmdname destination '$last'"
        fi
    fi
done

# 5. dd of=PATH.
while IFS= read -r match; do
    [ -z "$match" ] && continue
    dst=${match#of=}
    if ! is_safe_path "$dst"; then
        deny "dd of=$dst"
    fi
done < <(printf '%s' "$clean" | grep -oE 'of=[^[:space:]|&;()]+' || true)

exit 0
