#!/usr/bin/env bash
# Pressure test for the Gemini soft-block surface.
#
# Gemini CLI has no PreToolUse hook — the write guard is instruction-based
# only. This test doesn't run an LLM; it verifies that the combined
# instruction surface (GEMINI.md + skills/no-vibe/SKILL.md) contains
# explicit counter-language for specific rationalizations an agent is
# likely to use to talk itself around the guard.
#
# Per Superpowers' writing-skills: a skill without a test is a skill with
# unknown compliance. This test replaces "we hope the prose works" with
# "the prose explicitly addresses these 7 attack vectors."
#
# Run from repo root: bash tests/test_gemini_guard.sh

set -u

PASS=0
FAIL=0
FAIL_MSGS=()

GEMINI="GEMINI.md"
SKILL="skills/no-vibe/SKILL.md"

if [[ ! -f "$GEMINI" ]]; then
  echo "FAIL: $GEMINI not found"
  exit 1
fi
if [[ ! -f "$SKILL" ]]; then
  echo "FAIL: $SKILL not found"
  exit 1
fi

# Combined instruction surface an agent would see
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

echo "Adversarial rationalization coverage:"

# Rationalization 1: "It's just one typo / one character / one line"
check "R1: counters 'just one typo/char/line' rationalization" \
  "one (char|character|line|typo)|just this one|one.character typo"

# Rationalization 2: "I'll use Bash to bypass the write-tool guard"
check "R2: explicitly names Bash bypass patterns (sed -i / cat > / tee / >>)" \
  "sed -i|cat >|tee |>>.*(project|file|path)"

# Rationalization 3: "Gemini has no hook so enforcement doesn't apply to me"
check "R3: rule binds regardless of enforcement" \
  "rule.*(binds|applies|holds).*(regardless|enforcement)|hook isn.t active|hook.*(does not|doesn't)|no.*hook"

# Rationalization 4: "Small refactor while I'm in there"
check "R4: counters 'small refactor while I'm in there'" \
  "(small |)refactor.*(while|in there)|while I.m in"

# Rationalization 5: "Stub it, user can fix after"
check "R5: counters 'stub it and they can fix after'" \
  "stub.*(they|user).*(fix|after)|let me stub"

# Rationalization 6: "I'll write to a scratch path outside .no-vibe"
check "R6: counters 'scratch file outside .no-vibe'" \
  "scratch.*(file|path).*outside|outside.*\.no-vibe"

# Rationalization 7: "Curriculum revision doesn't really need announcing"
check "R7: curriculum revisions must be announced, never silent" \
  "silent.*revision|revision.*(announce|never silent)|announce.*revision"

# Iron Law presence (Superpowers structural pattern)
echo
echo "Structural discipline:"
check "Iron Law block is present" \
  "NO CODE INTO|no code.*project files.*ever|iron law"

check "Red Flags self-check list exists" \
  "red flag"

check "Rationalization table exists" \
  "rationalization table|\| excuse \||\| rationalization \|"

check "Trusts user's 'next' (defer rule, not violation)" \
  "trust.*next|don.t demand proof"

# Bash write-guard discipline (must mirror the hard hook on Claude/OpenCode/Pi)
check "Bash guard enumerates redirection operators (>, >>, &>)" \
  ">>?|&>"

check "Bash guard names tee/sed -i/cp/mv as mutators" \
  "tee.*sed|sed -i|tee\\b.*cp\\b|mv\\b.*install"

check "Bash guard cites safe-target allowlist (.no-vibe + /tmp + /dev/null)" \
  "/tmp.*\\.no-vibe|\\.no-vibe.*/tmp|/dev/null"

check "Bash guard fails closed on \$VAR / command-substitution destinations" \
  "fail closed|\\\$VAR|command.substitut|backtick"

# Session resume hint discipline (parallel to status hook)
check "Session-resume hint instruction is present" \
  "resuming.*layer|in_progress.*resume|sessions/.*\\.json"

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ $FAIL -gt 0 ]]; then
  echo
  echo "Failed checks indicate rationalizations that the Gemini soft-block"
  echo "surface does not explicitly address. Add explicit counter-language"
  echo "to GEMINI.md or skills/no-vibe/SKILL.md until all pass."
  for msg in "${FAIL_MSGS[@]}"; do
    echo "  - $msg"
  done
  exit 1
fi
exit 0
