#!/usr/bin/env bash
# Pressure test for the Gemini soft-block surface.
#
# Gemini CLI has no PreToolUse hook — the write guard is instruction-based
# only. This test verifies the combined instruction surface
# (runtimes/gemini/GEMINI.md + shared/skill/SKILL.md) contains explicit
# language for the rationalizations an agent might use to bypass the guard,
# plus the v2 memory contract.

set -u

PASS=0
FAIL=0
FAIL_MSGS=()

GEMINI="runtimes/gemini/GEMINI.md"
SKILL="shared/skill/SKILL.md"

if [[ ! -f "$GEMINI" ]]; then
  echo "FAIL: $GEMINI not found (run scripts/sync.sh first)"
  exit 1
fi
if [[ ! -f "$SKILL" ]]; then
  echo "FAIL: $SKILL not found"
  exit 1
fi

COMBINED="$(cat "$GEMINI" "$SKILL")"

check() {
  local name="$1"
  local pattern="$2"
  if echo "$COMBINED" | grep -qiE "$pattern"; then
    printf '  \033[32mPASS\033[0m %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  \033[31mFAIL\033[0m %s (pattern not found: %s)\n' "$name" "$pattern"
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("$name")
  fi
}

echo "Iron Law and rationalization coverage:"

check "Iron Law block is present" \
  "no code into|never write|iron law"

check "R1: 'just one typo/char/line'" \
  "one character|just this one|one line"

check "R2: explicitly names Bash bypass patterns" \
  "sed -i|tee |>>?|&>"

check "R3: rule binds regardless of enforcement (Codex/Gemini have no hook)" \
  "instruction-enforced|hook.*(no|missing)|binds regardless"

check "R4: 'small refactor while I'm in there'" \
  "small refactor|while.*in there|in there"

check "R5: 'stub it and let them fix it'" \
  "stub.*(fix|after)|stub.*them"

echo
echo "Bash write-guard discipline:"

check "Bash guard enumerates redirection operators (>, >>, &>)" \
  ">>?|&>"

check "Bash guard names tee/sed -i/cp/mv as mutators" \
  "tee.*sed|sed -i|cp.*mv|mv.*install"

check "Bash guard cites safe-target allowlist" \
  "/tmp.*\\.no-vibe|\\.no-vibe.*/tmp|safe-target"

check "Bash guard fails closed on variable destinations" \
  "fail closed|\\\$VAR|command.substitut|backtick"

echo
echo "v2 memory contract:"

check "Two NO-VIBE.md files mentioned (global + project)" \
  "NO-VIBE\\.md"

check "Eight-clause default style mentioned" \
  "12-year|feynman|eight clause|plain words"

check "Memory archive folder mentioned" \
  "memory/|archive"

check "Status line / session resume hint" \
  "session\\.md|resuming.*layers|no-vibe: ON"

echo
echo "v1 artifacts must be ABSENT (regression check):"

absent_check() {
  local name="$1"
  local pattern="$2"
  if echo "$COMBINED" | grep -qE "$pattern"; then
    printf '  \033[31mFAIL\033[0m %s (forbidden pattern present: %s)\n' "$name" "$pattern"
    FAIL=$((FAIL + 1))
    FAIL_MSGS+=("$name")
  else
    printf '  \033[32mPASS\033[0m %s\n' "$name"
    PASS=$((PASS + 1))
  fi
}

absent_check "no Turn Response Contract header" \
  "Turn Response Contract|\\[no-vibe\\] Phase:"
absent_check "no mistakes.json references" \
  "mistakes\\.json"
absent_check "no ai-notes.json references" \
  "ai-notes\\.json"
absent_check "no DATA-SCHEMA references" \
  "DATA-SCHEMA"
absent_check "no pck_gap enum" \
  "pck_gap"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo
  for msg in "${FAIL_MSGS[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
exit 0
