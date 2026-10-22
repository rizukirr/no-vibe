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

assert_eq '"a\\b\"c"' "$(json_string 'a\b"c')" "json_string doubles a backslash before a quote"
if awk --version 2>/dev/null | grep -q 'GNU Awk'; then
    assert_eq '"a\\b\"c"' "$(POSIXLY_CORRECT=1 json_string 'a\b"c')" "json_string doubles backslashes under POSIX gawk"
fi
ctl=$(json_string $'a\x01b\bc\x1bd')
assert_eq '"a\u0001b\bc\u001bd"' "$ctl" "json_string escapes control characters"
assert_eq $'a\x01b\bc\x1bd' "$(get "{\"m\":$ctl}" .m)" "escaped control characters decode back"
assert_eq $'x\\' "$(get "{\"m\":$(json_string 'x\')}" .m)" "trailing backslash round-trips"

assert_eq "b" "$(get $'\xef\xbb\xbf{"a":"b"}' .a)" "leading UTF-8 BOM is skipped"
assert_eq "src/x" "$(get '{"tool_input":{"file_path":"src/x"},"tool_input.file_path":".no-vibe/x"}' .tool_input.file_path)" "dotted top-level key does not shadow the nested path"
assert_eq "i" "$(get '{"a[0]":"k","a":["i"]}' '.a[0]')" "bracketed key does not shadow an array index"

# Timing check: a 1 MB string value must decode in well under the 10 s hook
# timeout on every awk.
big=$(printf '%076924d' 0 | sed 's/0/ab\\"cd\\n\\\\ef /g')
start=$(date +%s)
len=$(get "{\"a\":\"$big\",\"b\":\"ok\"}" .a | wc -c)
took=$(( $(date +%s) - start ))
[ "$len" -gt 500000 ] && [ "$took" -lt 5 ] && pass "timing: 1 MB string read in ${took}s" || fail "timing: 1 MB string read" "bytes=$len seconds=$took"

# Escapes are validated in every string, including ones the reader skips.
for doc in '{"a":"\u12"}' '{"a":"\u"}' '{"a":"\u12zz"}' '{"a":"\q"}' '{"b":"\u12","a":"y"}' '{"a":"y","b":["\u12"]}' '{"\u12":"x","a":"y"}'; do
    get "$doc" .a >/dev/null; assert_eq "2" "$?" "malformed escape → exit 2: $doc"
done
assert_eq '"\/' "$(get '{"b":"\\\"","a":"\"\\\/"}' .a)" "valid escapes after a skipped escaped quote"

# A surrogate escape is valid only as a high half followed by a low half.
for doc in '{"a":"\ud83d"}' '{"a":"\ud83dx"}' '{"a":"\ud83d\u0041"}' '{"a":"\ud83d\ud83d"}' '{"a":"\ude00"}' '{"a":"\ud83d\n"}' '{"b":"\ud83d\u0041","a":"y"}'; do
    get "$doc" .a >/dev/null; assert_eq "2" "$?" "unpaired surrogate → exit 2: $doc"
done
assert_eq "😀z" "$(get '{"a":"\uD83D\uDE00z"}' .a)" "surrogate pair still decodes"

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
