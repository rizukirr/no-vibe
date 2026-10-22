#!/usr/bin/env bash
# Antigravity PreToolUse adapter. Antigravity sends {toolCall:{name,args},
# workspacePaths:[...]} and reads {"decision":...} on stdout, so the payload
# is mapped to the Claude hook JSON and the shared guards decide.

set -u
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$HOOK_DIR/json.sh"

input=$(cat)

name=$(json_get .toolCall.name)
# JSON this reader cannot parse is refused while no-vibe is active.
if [ $? -eq 2 ]; then
    if [ -f "$PWD/.no-vibe/active" ]; then
        echo '{"decision":"deny","reason":"no-vibe mode is active. The tool call could not be parsed."}'
    else
        echo '{"decision":"allow"}'
    fi
    exit 0
fi
cwd=$(json_get '.workspacePaths[0]')

# no-vibe: run_command resolves relative paths against the workspace root, not
# args.Cwd. A command run from a subdirectory can be misjudged. Upgrade path:
# prefix the command with a cd to args.Cwd once block-bash-writes.sh parses cd.
case "$name" in
    write_to_file|replace_file_content|multi_replace_file_content)
        script=block-writes.sh
        target=$(json_get .toolCall.args.TargetFile)
        payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":$(json_string "$target")},\"cwd\":$(json_string "$cwd")}"
        ;;
    run_command)
        script=block-bash-writes.sh
        command=$(json_get .toolCall.args.CommandLine)
        payload="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(json_string "$command")},\"cwd\":$(json_string "$cwd")}"
        ;;
    *)
        echo '{"decision":"allow"}'
        exit 0
        ;;
esac

if reason=$(printf '%s' "$payload" | bash "$HOOK_DIR/$script" 2>&1 >/dev/null); then
    echo '{"decision":"allow"}'
else
    printf '{"decision":"deny","reason":%s}\n' "$(json_string "$reason")"
fi
exit 0
