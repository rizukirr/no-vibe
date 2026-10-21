# no-vibe JSON helpers, sourced by the hook scripts. Hosts hand hooks their
# tool call as JSON on stdin, and no JSON tool can be assumed on the user's
# machine. POSIX awk ships wherever bash does, so the reader is awk.

# Reads one JSON document on stdin and prints the decoded string value at the
# path in `want` (`.a.b[0].c`). Exit 0 found, 1 missing or not a string,
# 2 malformed JSON. A key that appears twice resolves to its last value.
NO_VIBE_JSON_AWK='
function ws() { while (pos <= n && index(" \t\r\n", substr(s, pos, 1))) pos++ }
function hex(h,   i, v) {
    v = 0
    for (i = 1; i <= 4; i++) v = v * 16 + index("0123456789abcdef", tolower(substr(h, i, 1))) - 1
    return v
}
function utf8(c) {
    if (c < 128) return sprintf("%c", c)
    if (c < 2048) return sprintf("%c%c", 192 + int(c / 64), 128 + c % 64)
    if (c < 65536) return sprintf("%c%c%c", 224 + int(c / 4096), 128 + int(c / 64) % 64, 128 + c % 64)
    return sprintf("%c%c%c%c", 240 + int(c / 262144), 128 + int(c / 4096) % 64, 128 + int(c / 64) % 64, 128 + c % 64)
}
function str(   out, c, code, low) {
    pos++
    out = ""
    while (pos <= n) {
        c = substr(s, pos, 1)
        if (c == "\"") { pos++; return out }
        if (c != "\\") { out = out c; pos++; continue }
        c = substr(s, pos + 1, 1)
        pos += 2
        if (c == "n") out = out "\n"
        else if (c == "t") out = out "\t"
        else if (c == "r") out = out "\r"
        else if (c == "b") out = out "\b"
        else if (c == "f") out = out "\f"
        else if (c == "u") {
            code = hex(substr(s, pos, 4))
            pos += 4
            if (code >= 55296 && code < 56320 && substr(s, pos, 2) == "\\u") {
                low = hex(substr(s, pos + 2, 4))
                pos += 6
                code = 65536 + (code - 55296) * 1024 + (low - 56320)
            }
            out = out utf8(code)
        }
        else out = out c
    }
    bad = 1
    return out
}
function value(path,   c, k, i, v) {
    ws()
    c = substr(s, pos, 1)
    if (c == "{") {
        pos++
        ws()
        if (substr(s, pos, 1) == "}") { pos++; return }
        while (!bad) {
            ws()
            if (substr(s, pos, 1) != "\"") { bad = 1; return }
            k = str()
            ws()
            if (substr(s, pos, 1) != ":") { bad = 1; return }
            pos++
            value(path "." k)
            ws()
            c = substr(s, pos, 1)
            pos++
            if (c == "}") return
            if (c != ",") { bad = 1; return }
        }
        return
    }
    if (c == "[") {
        pos++
        ws()
        if (substr(s, pos, 1) == "]") { pos++; return }
        for (i = 0; !bad; i++) {
            value(path "[" i "]")
            ws()
            c = substr(s, pos, 1)
            pos++
            if (c == "]") return
            if (c != ",") { bad = 1; return }
        }
        return
    }
    if (c == "\"") {
        v = str()
        if (path == want) { found = 1; result = v }
        return
    }
    if (c == "" || index(",]}:", c)) { bad = 1; return }
    while (pos <= n && !index(",]} \t\r\n", substr(s, pos, 1))) pos++
}
{ s = s $0 "\n" }
END {
    n = length(s)
    pos = 1
    value("")
    ws()
    if (bad || pos <= n) exit 2
    if (!found) exit 1
    printf "%s", result
}'

# json_get PATH: prints the string at PATH in $input.
json_get() {
    printf '%s' "$input" | LC_ALL=C awk -v want="$1" "$NO_VIBE_JSON_AWK"
}

# json_string TEXT: prints TEXT as a quoted JSON string.
json_string() {
    printf '%s' "$1" | LC_ALL=C awk '
        { s = (NR > 1 ? s "\n" : "") $0 }
        END {
            gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
            gsub(/\n/, "\\n", s); gsub(/\r/, "\\r", s); gsub(/\t/, "\\t", s)
            printf "\"%s\"", s
        }'
}
