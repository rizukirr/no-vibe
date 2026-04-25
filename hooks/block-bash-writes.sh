#!/usr/bin/env bash
# no-vibe PreToolUse hook for Bash: blocks shell writes outside .no-vibe/
# and /tmp/ when .no-vibe/active exists. Closes the documented Bash
# loophole in SKILL.md by parsing the command for redirections and
# common write commands (tee, sed -i, cp, mv, install, dd of=).
#
# Errs strict: when a dangerous pattern is detected and the destination
# can't be cleanly resolved to a safe path, we deny. Show the code in
# chat instead — the user can run /no-vibe off if they truly need it.
#
# Reads tool call as JSON on stdin. Exit 0 = allow, non-zero = deny.

set -u

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')

# If marker doesn't exist, allow everything.
if [ -z "$cwd" ] || [ ! -f "$cwd/.no-vibe/active" ]; then
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
[ "$tool_name" = "Bash" ] || exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

deny() {
    cat >&2 <<EOF
no-vibe mode is active. Refusing Bash command that writes outside the
safe-target allowlist:

  $cmd

Reason: $1

Safe targets (writes allowed): \`.no-vibe/**\`, \`/tmp/**\`, \`/var/tmp/**\`,
\`/dev/null\`, \`/dev/stdout\`, \`/dev/stderr\`, \`/dev/tty\`, \`/dev/fd/*\`.
Variable or command-substitution destinations (\`\$VAR\`, \`\$(…)\`, backticks)
fail closed.

Show the code in chat and let the user type/run it themselves.
To exit no-vibe mode, the user can run \`/no-vibe off\`.
EOF
    exit 2
}

# Resolve canonical .no-vibe root once.
if command -v realpath >/dev/null 2>&1; then
    scratch_root=$(realpath -m "$cwd/.no-vibe")
else
    scratch_root="$cwd/.no-vibe"
fi

is_safe_path() {
    local p="$1"
    # Strip surrounding quotes (single or double).
    case "$p" in
        \"*\") p=${p#\"}; p=${p%\"} ;;
        \'*\') p=${p#\'}; p=${p%\'} ;;
    esac
    [ -z "$p" ] && return 1
    # Reject env-var or command-substitution destinations — we can't
    # statically reason about them, so fail closed.
    case "$p" in
        *\$\(*|*\`*|*\$\{*|\$*) return 1 ;;
    esac
    case "$p" in
        /dev/null|/dev/stdout|/dev/stderr|/dev/fd/*|/dev/tty) return 0 ;;
        /tmp|/tmp/*|/var/tmp|/var/tmp/*) return 0 ;;
    esac
    local abs
    case "$p" in
        /*) abs="$p" ;;
        *)  abs="$cwd/$p" ;;
    esac
    if command -v realpath >/dev/null 2>&1; then
        abs=$(realpath -m "$abs" 2>/dev/null || echo "$abs")
    fi
    case "$abs" in
        "$scratch_root"|"$scratch_root"/*) return 0 ;;
        /tmp|/tmp/*|/var/tmp|/var/tmp/*) return 0 ;;
    esac
    return 1
}

# Strip fd-duplication forms (`2>&1`, `1>&2`, `<&3`) so they don't
# get mistaken for output redirection. Keep `&>` / `&>>` (which DO
# write to a file).
clean=$(printf '%s' "$cmd" | sed -E 's/[0-9]+>&[0-9]+//g; s/[0-9]+<&[0-9]+//g')

# 1. Output redirection: `>`, `>>`, `&>`, `&>>` followed by a path.
#    Use grep -oE to enumerate all redirection targets.
while IFS= read -r match; do
    [ -z "$match" ] && continue
    target=$(printf '%s' "$match" | sed -E 's/^(&>>?|>>?)[[:space:]]*//')
    if ! is_safe_path "$target"; then
        deny "redirection writes to '$target' outside .no-vibe/ or /tmp/"
    fi
done < <(printf '%s' "$clean" | grep -oE '(&>>?|>>?)[[:space:]]*[^[:space:]|&;<>()]+' || true)

# Helper: walk space-split tokens after a command keyword, calling a
# callback with each positional (non-flag) token. Stops at a shell
# operator. Used by tee/sed/cp/mv/install scanners.

# 2. tee — first non-flag arg is the destination file (additional args
#    are extra destinations; -a means append, still a write).
if printf '%s' "$clean" | grep -qE '(^|[[:space:]|;&(])tee([[:space:]]|$)'; then
    tee_args=$(printf '%s' "$clean" | sed -E 's/.*([[:space:]|;&(])tee[[:space:]]+/ /; t; s/^tee[[:space:]]+//')
    for tok in $tee_args; do
        case "$tok" in
            -*) continue ;;
            \||\&\&|\|\||\;|\)|\() break ;;
            *)
                if ! is_safe_path "$tok"; then
                    deny "tee writes to '$tok' outside .no-vibe/ or /tmp/"
                fi
                ;;
        esac
    done
fi

# 3. sed -i / sed --in-place — mutates files in place.
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
                if [ "$saw_script" = "0" ]; then
                    saw_script=1
                    continue
                fi
                if ! is_safe_path "$tok"; then
                    deny "sed -i mutates '$tok' outside .no-vibe/ or /tmp/"
                fi
                ;;
        esac
    done
fi

# 4. cp / mv / install — destination is the last positional arg.
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
            deny "$cmdname destination '$last' outside .no-vibe/ or /tmp/"
        fi
    fi
done

# 5. dd of=PATH — output file is explicit.
while IFS= read -r match; do
    [ -z "$match" ] && continue
    dst=${match#of=}
    if ! is_safe_path "$dst"; then
        deny "dd of=$dst writes outside .no-vibe/ or /tmp/"
    fi
done < <(printf '%s' "$clean" | grep -oE 'of=[^[:space:]|&;()]+' || true)

exit 0
