# no-vibe JSON helpers, sourced by the hook scripts. Hosts hand hooks their
# tool call as JSON on stdin, and no JSON tool can be assumed on the user's
# machine. POSIX awk ships wherever bash does, so the reader is awk.
#
# The code runs on gawk, mawk and busybox awk. mawk and busybox copy a string
# on every concatenation, and busybox measures the whole string on every
# substr, so nothing here walks a long string one character at a time or
# grows a string piece by piece. Long strings are cut with split and put back
# together with join.

# Reads one JSON document on stdin and prints the decoded string value at the
# path in `want` (`.a.b[0].c`). Exit 0 found, 1 missing or not a string,
# 2 malformed JSON. A key that appears twice resolves to its last value.
NO_VIBE_JSON_AWK='
# Concatenates A[1..m] pairwise, so each byte is copied log2(m) times.
function join(A, m,   i, h) {
    if (m < 1) return ""
    while (m > 1) {
        h = 0
        for (i = 1; i <= m; i += 2) A[++h] = (i < m) ? A[i] A[i + 1] : A[i]
        m = h
    }
    return A[1]
}
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
# Cuts the document at every quote and backslash. P[k] is the text before the
# k-th cut and S[k] the character cut there, "" after the last segment.
function segments(   i, j, nq, nb, Q, B) {
    nq = split(s, Q, "\"")
    M = 0
    for (i = 1; i <= nq; i++) {
        nb = split(Q[i], B, "\\")
        if (nb == 0) { nb = 1; B[1] = "" }
        for (j = 1; j <= nb; j++) {
            P[++M] = B[j]
            S[M] = (j < nb) ? "\\" : ((i < nq) ? "\"" : "")
        }
    }
}
# Walks a string whose text starts at segment k and returns the segment that
# ends at its closing quote. An escape is the first character of the segment
# after a backslash, or the next cut when that segment is empty.
function skip(k) {
    while (k <= M) {
        if (S[k] == "\"") return k
        if (S[k] == "") break
        k++
        if (P[k] == "") {
            if (S[k] == "") break
            k++
        }
    }
    bad = 1
    return M
}
# Decodes the string that starts at segment k.
function decode(k,   d, D, p, c, code, low) {
    d = 0
    D[++d] = P[k]
    while (S[k] == "\\") {
        p = P[++k]
        if (p == "") { D[++d] = S[k]; D[++d] = P[++k]; continue }
        c = substr(p, 1, 1)
        if (c == "u") {
            code = hex(substr(p, 2, 4))
            p = substr(p, 6)
            if (code >= 55296 && code < 56320 && p == "" && S[k] == "\\" && substr(P[k + 1], 1, 1) == "u") {
                low = hex(substr(P[++k], 2, 4))
                p = substr(P[k], 6)
                code = 65536 + (code - 55296) * 1024 + (low - 56320)
            }
            D[++d] = utf8(code) p
            continue
        }
        if (c == "n") c = "\n"
        else if (c == "t") c = "\t"
        else if (c == "r") c = "\r"
        else if (c == "b") c = "\b"
        else if (c == "f") c = "\f"
        D[++d] = c substr(p, 2)
    }
    return join(D, d)
}
# Turns the segments into tokens: TT[t] is one of {}[]:, or "s" for a string
# that starts at segment TK[t], or "l" for a number, true, false or null.
function tokens(   k, p, c, i, L) {
    T = 0
    for (k = 1; k <= M; k++) {
        p = P[k]
        L = length(p)
        for (i = 1; i <= L; i++) {
            c = substr(p, i, 1)
            if (index(" \t\r\n", c)) continue
            if (index("{}[]:,", c)) { TT[++T] = c; continue }
            while (i < L && !index("{}[]:, \t\r\n", substr(p, i + 1, 1))) i++
            TT[++T] = "l"
        }
        if (S[k] == "") return
        if (S[k] == "\\") { bad = 1; return }
        TT[++T] = "s"
        TK[T] = k + 1
        k = skip(k + 1)
        if (bad) return
    }
}
# Object keys join the path after \034 and array indexes after \035, so a key
# that contains a dot or a bracket cannot pass for a nested path.
function value(path,   t, k, i) {
    t = TT[++ti]
    if (t == "{") {
        if (TT[ti + 1] == "}") { ti++; return }
        while (!bad) {
            if (TT[++ti] != "s") { bad = 1; return }
            k = decode(TK[ti])
            if (TT[++ti] != ":") { bad = 1; return }
            value(path "\034" k)
            t = TT[++ti]
            if (t == "}") return
            if (t != ",") { bad = 1; return }
        }
        return
    }
    if (t == "[") {
        if (TT[ti + 1] == "]") { ti++; return }
        for (i = 0; !bad; i++) {
            value(path "\035" i)
            t = TT[++ti]
            if (t == "]") return
            if (t != ",") { bad = 1; return }
        }
        return
    }
    if (t == "s") {
        if (path == want) { found = 1; result = decode(TK[ti]) }
        return
    }
    if (t != "l") bad = 1
}
{ L[NR] = $0 "\n" }
END {
    gsub(/\./, "\034", want)
    gsub(/\[/, "\035", want)
    gsub(/\]/, "", want)
    s = join(L, NR)
    if (substr(s, 1, 3) == "\357\273\277") s = substr(s, 4)
    segments()
    tokens()
    ti = 0
    if (!bad) value("")
    if (bad || ti != T) exit 2
    if (!found) exit 1
    printf "%s", result
}'

# json_get PATH: prints the string at PATH in $input.
json_get() {
    printf '%s' "$input" | LC_ALL=C awk -v want="$1" "$NO_VIBE_JSON_AWK"
}

# json_string TEXT: prints TEXT as a quoted JSON string. The x after TEXT
# keeps a trailing newline in TEXT from ending the last record unseen.
json_string() {
    printf '%sx' "$1" | LC_ALL=C awk '
        function join(A, m,   i, h) {
            if (m < 1) return ""
            while (m > 1) {
                h = 0
                for (i = 1; i <= m; i += 2) A[++h] = (i < m) ? A[i] A[i + 1] : A[i]
                m = h
            }
            return A[1]
        }
        # Replaces every ch in t with rep. split and join, not gsub: gsub
        # reads backslashes in its replacement differently across awks.
        function swap(t, ch, rep,   A, m, i) {
            if (!index(t, ch)) return t
            m = split(t, A, ch)
            for (i = 1; i < m; i++) A[i] = A[i] rep
            return join(A, m)
        }
        { L[NR] = $0 }
        END {
            L[NR] = substr(L[NR], 1, length(L[NR]) - 1)
            for (r = 1; r <= NR; r++) {
                t = swap(L[r], "\\", "\\\\")
                t = swap(t, "\"", "\\\"")
                for (c = 1; c < 32; c++) {
                    if (c == 10) continue
                    ch = sprintf("%c", c)
                    if (c == 8) e = "\\b"
                    else if (c == 9) e = "\\t"
                    else if (c == 12) e = "\\f"
                    else if (c == 13) e = "\\r"
                    else e = sprintf("\\u%04x", c)
                    t = swap(t, ch, e)
                }
                L[r] = (r < NR) ? t "\\n" : t
            }
            printf "\"%s\"", join(L, NR)
        }'
}
