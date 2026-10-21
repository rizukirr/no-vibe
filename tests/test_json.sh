#!/usr/bin/env bash
# Tests for hooks/json.sh, and for the guards running with only bash and the
# POSIX tools on PATH.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$SCRIPT_DIR/../hooks"
. "$SCRIPT_DIR/helpers.sh"
. "$HOOKS/json.sh"

get() { input="$1"; json_get "$2"; }

assert_eq "/a b/c" "$(get '{"cwd":"/a b/c","tool_name":"Write"}' .cwd)" "top-level string"
assert_eq 'echo "hi" > x' "$(get '{"tool_input":{"command":"echo \"hi\" > x"}}' .tool_input.command)" "escaped quotes"
assert_eq $'a\nb' "$(get '{"c":"a\nb"}' .c)" "escaped newline"
assert_eq 'a&b é back\slash' "$(get '{"p":"a&b é back\\slash"}' .p)" "unicode and backslash escapes"
assert_eq "😀" "$(get '{"p":"😀"}' .p)" "surrogate pair"
assert_eq "/w2" "$(get '{"workspacePaths":["/w1","/w2"]}' '.workspacePaths[1]')" "array index"
assert_eq "x" "$(get '{"a":1,"b":true,"c":null,"d":[1,{"e":"x"}],"f":-2.5e3}' '.d[1].e')" "nested past numbers, booleans and null"
assert_eq "y" "$(get '{"a":"x","a":"y"}' .a)" "duplicate key resolves to last"
assert_eq "/real" "$(get '{"k":"\"cwd\":\"/fake\"","cwd":"/real"}' .cwd)" "key text inside a string is not a key"
assert_eq "/p" "$(get $'{\n  "cwd": "/p",\n  "x": [ ]\n}\n' .cwd)" "pretty-printed input"

get '{"a":1}' .a >/dev/null; assert_eq "1" "$?" "non-string value → exit 1"
get '{"a":"x"}' .b >/dev/null; assert_eq "1" "$?" "missing key → exit 1"
get '{"a":' .a >/dev/null; assert_eq "2" "$?" "truncated JSON → exit 2"
get 'not json' .a >/dev/null; assert_eq "2" "$?" "not JSON → exit 2"
get '{"a":"x"} trailing' .a >/dev/null; assert_eq "2" "$?" "trailing garbage → exit 2"

round=$(json_string $'q"x\\y\nz\tw')
assert_eq $'q"x\\y\nz\tw' "$(get "{\"m\":$round}" .m)" "json_string round-trips through json_get"

# The guards with only bash and the POSIX tools on PATH. Projects live
# outside /tmp, which the Bash guard allow-lists.
bin=$(mktemp -d)
for tool in bash awk sed grep tr head realpath dirname basename printf cat; do
    ln -s "$(command -v "$tool")" "$bin/$tool"
done
sandbox="${HOME:-/root}/.no-vibe-test-sandbox"
mkdir -p "$sandbox"
proj=$(mktemp -d -p "$sandbox")
mkdir -p "$proj/.no-vibe" && touch "$proj/.no-vibe/active"

run() { printf '%s' "$2" | PATH="$bin" bash "$HOOKS/$1" >/dev/null 2>&1; echo $?; }
write_call() { printf '{"tool_name":"Write","tool_input":{"file_path":%s},"cwd":%s}' "$(json_string "$1")" "$(json_string "$proj")"; }

assert_eq "2" "$(run block-writes.sh "$(write_call "$proj/src/x.py")")" "minimal PATH: project write refused"
assert_eq "0" "$(run block-writes.sh "$(write_call "$proj/.no-vibe/notes.md")")" "minimal PATH: .no-vibe write allowed"
assert_eq "2" "$(run block-bash-writes.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"echo hi > x.py"},"cwd":%s}' "$(json_string "$proj")")")" "minimal PATH: bash redirect refused"
assert_eq "0" "$(run block-bash-writes.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"},"cwd":%s}' "$(json_string "$proj")")")" "minimal PATH: read-only bash allowed"

agy=$(printf '{"toolCall":{"name":"write_to_file","args":{"TargetFile":%s}},"workspacePaths":[%s]}' "$(json_string "$proj/src/x.py")" "$(json_string "$proj")" |
    PATH="$bin" bash "$HOOKS/agy-guard.sh")
assert_contains "$agy" '"decision":"deny"' "minimal PATH: agy project write denied"

garbled=$(cd "$proj" && printf 'not json' | PATH="$bin" bash "$HOOKS/block-writes.sh" >/dev/null 2>&1; echo $?)
assert_eq "2" "$garbled" "unparseable call refused while the hook's cwd is active"

rm -rf "$proj" "$bin"
summary
