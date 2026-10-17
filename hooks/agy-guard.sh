#!/usr/bin/env bash
# Antigravity PreToolUse adapter. Antigravity sends {toolCall:{name,args},
# workspacePaths:[...]} and reads {"decision":...} on stdout, so the payload
# is mapped to the Claude hook JSON and the shared guards decide.

set -u
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspacePaths[0] // empty')
name=$(echo "$input" | jq -r '.toolCall.name // empty')

# no-vibe: run_command resolves relative paths against the workspace root, not
# args.Cwd. A command run from a subdirectory can be misjudged. Upgrade path:
# prefix the command with a cd to args.Cwd once block-bash-writes.sh parses cd.
case "$name" in
    write_to_file|replace_file_content|multi_replace_file_content)
        script=block-writes.sh
        payload=$(echo "$input" | jq -c --arg cwd "$cwd" \
            '{tool_name:"Write", tool_input:{file_path:.toolCall.args.TargetFile}, cwd:$cwd}')
        ;;
    run_command)
        script=block-bash-writes.sh
        payload=$(echo "$input" | jq -c --arg cwd "$cwd" \
            '{tool_name:"Bash", tool_input:{command:.toolCall.args.CommandLine}, cwd:$cwd}')
        ;;
    *)
        echo '{"decision":"allow"}'
        exit 0
        ;;
esac

if reason=$(printf '%s' "$payload" | bash "$HOOK_DIR/$script" 2>&1 >/dev/null); then
    echo '{"decision":"allow"}'
else
    jq -cn --arg reason "$reason" '{decision:"deny", reason:$reason}'
fi
exit 0
