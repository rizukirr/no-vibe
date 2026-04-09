#!/usr/bin/env bash
# Shared test helpers for no-vibe hook tests.

set -u

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf "  \033[32mPASS\033[0m %s\n" "$1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    printf "  \033[31mFAIL\033[0m %s\n" "$1"
    [ -n "${2:-}" ] && printf "       %s\n" "$2"
}

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$name"
    else
        fail "$name" "expected: $expected | actual: $actual"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" name="$3"
    if echo "$haystack" | grep -qF "$needle"; then
        pass "$name"
    else
        fail "$name" "expected output to contain: $needle"
        fail "$name" "actual: $haystack"
    fi
}

summary() {
    echo
    printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m\n" \
        "$PASS_COUNT" "$FAIL_COUNT"
    [ "$FAIL_COUNT" -eq 0 ]
}
