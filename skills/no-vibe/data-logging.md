# no-vibe — Data Logging Procedures

Load this when logging a user error, logging an ai-note, running the pre-turn audit, or closing a session. Field contracts live in DATA-SCHEMA.md.

## Before any write

Ensure target file exists. If missing, initialize with schema default (`[]` for the JSON logs, empty file for profile.md).

All project JSON writes use the per-project `.no-vibe/data/.lock` (two-tier PID-verified, `[future-runtime]`) + tmp+rename atomic protocol. Current implementation: AI uses Edit tool; atomicity is aspirational until the plugin runtime ships. Still follow the discipline.

## Teaching-gap logging (Phase 4, and any phase where user errs)

**`mistakes.json` records *teaching failures*, not learner flaws.** Every entry captures the AI teaching move that caused the user's error, plus the corrective action AI will apply next turn.

When the user errs (wrong code, wrong answer, visible confusion):

1. **Clarify and guide the fix in chat first.** User gets unblocked before logging.
2. **Reflect-on-action** (Schön): scan your last 2–3 AI turns. Pick the specific teaching move that led to the mistake. `pck_gap` enum:
   - `buried-key-rule` — the rule that mattered was hidden in prose
   - `missing-analogy` — abstract without a concrete anchor
   - `wrong-sequencing` — introduced concept before prerequisite
   - `no-prereq-check` — assumed knowledge user didn't have
   - `jargon-overload` — unexplained terms stacked up
   - `jumped-abstraction` — skipped concrete → general bridge
   - `ambiguous-naming` — name conflated two meanings
   - `other` — explain in `gap_action`
3. **Diagnose cognitive load** (`load_mismatch`): `over-explained` | `under-scaffolded` | `correct`. Still log when `correct` — entry still captures the `pck_gap`.
4. **Formulate `gap_action`** (Black & Wiliam): one imperative sentence — what AI does differently next turn.
5. **Append to `.no-vibe/data/mistakes.json` with no-regression check.** Runtime mints `id` (`m-<unix-ms>-<counter>`), `created_at`, `revision_id_at_creation` — never generate these yourself. Acquire `.no-vibe/data/.lock` first. Pre-append scan:
   - Same `misconception_id` + same `pck_gap` + `applied=true` → **regression**. Update existing: `applied=false`, bump `retry_count`, overwrite `gap_action` with a sharper corrective. Do NOT duplicate.
   - Same `misconception_id` still `applied=false` → update existing in place. Don't stack.
   - Same `pck_gap`, similar wording → merge into existing. No near-duplicate.
   - Same `misconception_id`, different `pck_gap`, contradictory `gap_action` → mark old `applied=true` + supersede note; append new.
   - Same `misconception_id`, different `pck_gap`, *clearly* compatible `gap_action` → merge into existing (combine gap_actions, prefer more specific `pck_gap`). **When in doubt, default to the contradiction branch** — cheaper to over-supersede than silently merge distinct corrections.
   - Otherwise → append.
6. **Apply `gap_action` starting next turn.** Increment `errors_this_session` by 1 on every user error (regardless of append vs update). Increment `entries_this_session` only on a true new append. Legacy keys `gaps_this_session` / `mistakes_this_session` accepted on reads as `entries_this_session`.

`misconception_id` is kebab-case and reusable (e.g. `fencepost-off-by-one`). Drives future common-trap layers.

No writes to any global JSON. Cross-project aggregation is handled only by the session-end synth step (see below).

## AI-note logging (any turn, even outside active no-vibe mode)

When user offers correction, feedback, new request/rule, complaint, or preference, **immediately** append to `.no-vibe/data/ai-notes.json` before continuing the reply.

Runtime mints `id` (`a-<unix-ms>-<counter>`), `created_at`. Fields: `kind`, `category`, `summary`, `trigger` (or `null`), `directive`. `kind` ∈ {`correction`, `feedback`, `request`, `complaint`, `preference`}. Categories are kebab-case and reusable.

Acquire `.no-vibe/data/.lock`. No-regression check pre-append:

| Match condition | Action |
|---|---|
| Same `(kind, category, directive)` text | **Skip.** User said same thing twice |
| Same `category`, opposite `directive` | **Contradiction.** Move old entry to `ai-notes.archive.json` with `"superseded": "YYYY-MM-DD"` field. Append new to active file |
| Same `category`, more specific `directive` | **Refinement.** Update old entry in place |
| Otherwise | Append |

Log ai-notes even outside active no-vibe mode, as long as `.no-vibe/` exists on this project. Signal is about AI behavior, not lesson state.

## Pre-turn gap-action audit (every teaching reply)

If `errors_this_session >= 1`, scan recent project `mistakes.json` entries where `applied=false` AND `resolved_at` is null (cap last 5):

- Draft reply embodies `gap_action`? → flip `applied=true` before sending.
- Still relevant but draft doesn't reflect it? → revise draft before sending. Don't flip yet.
- No longer relevant (topic moved, user pivoted, layer changed)? → flip `applied=true` and append ` — superseded: <one-line reason>` to `gap_action`.

**Conflict tie-breaker.** Two active entries for same `misconception_id` but contradictory `gap_action`s → prefer newest entry (highest `created_at`).

**Resolution detection (Phase 4 review turn) — scoped:**

1. Only consider entries where current layer's conceptual territory matches the mistake's original territory. Because curriculum revisions can insert/collapse layers, the window shifts with revision history:
   - `shift = current_revision_id − entry.revision_id_at_creation`
   - Effective target layer = `entry.layer + shift`
   - Qualifies when: `entry.topic == session.topic` AND `abs(current_layer − (entry.layer + shift)) <= 3`
2. Within that window, when Phase 4 observes the specific `misconception_id` pattern used **correctly** (e.g. for `fencepost-off-by-one`: a loop bound that hits the right element count), append `{layer: current_layer, date: today}` to the entry's `correct_uses`.
3. If `applied == true` AND `len(correct_uses) >= 2` AND `resolved_at` is null → set `resolved_at = today`.
4. Resolved entries exit the audit pool and are excluded from future synth candidates + Phase 1a scaffolding.

Skip audit when `errors_this_session == 0` or on non-teaching turns (pure tool calls, status questions). Legacy entries without `applied` count as already applied.

This is reflection-in-action (Schön): self-policing within the turn.

## Session outcome (session end OR early close)

At Phase 6 or early close (`/no-vibe off`, fresh start over incomplete session):

- Session JSON: `status` → `completed` or `abandoned`; `layers_completed` → final count; `unapplied_gaps` → **map each `misconception_id` from this session's `applied=false` entries to its `pck_gap`, dedupe, store the `pck_gap` list** (never raw `misconception_id`s — those are project-local and fail the global purpose filter).
- Compute skill-level delta from `errors_this_session`:
  - `0` → up one level
  - `≤1 && layers_completed ≥ 5` → up one level
  - `≥3` → down one level
  - Otherwise → stay

The delta is NOT written to a separate file. Feeds the synth prompt (below) as "session outcome."

## Global profile synthesis (conditional)

Rewrites `~/.no-vibe/profile.md` using the **full-rewrite pattern** borrowed from DeepTutor: LLM receives current `profile.md` + new project evidence → emits merged whole, or returns unchanged.

**Trigger (either/or):**

- Session end (complete or early close)
- Project log has ≥3 new learner-level candidates since last synth

**Candidate filter — the purpose test.** For each new entry: *"Would I want AI to know this next time user opens a totally different project?"*

- In: teaching style, cross-domain skill calibration, recurring AI blind spots, stable preferences, directive rules.
- Out: lesson content, layer-level mistakes, project-local facts, session progress.

Additional exclusions: uuids in `pruning_cursor.<project>.*_synced_ids` (already in flight), entries with `resolved_at != null` or `superseded != null`.

Zero candidates survive → skip synth entirely. No file write.

**Synth procedure (summary — full algorithm in DATA-SCHEMA.md "Synth procedure"):**

1. Acquire `~/.no-vibe/.profile.lock` (two-tier, PID-verified, 5-min ceiling).
2. Load `.synth-state.json`. If `consecutive_failures ≥ 3`, skip this session. If `strict_audit_active`, inject strict prompt.
3. Read current `profile.md`.
4. Build filtered candidates with runtime-minted uuids.
5. Prompt LLM with full-rewrite rules (hard-line freeze, exact-match → bump evidence, semantic-match → keep no duplicate, refine → edit in place, contradict → move old to `profile.archive.md`, novel → append, else return unchanged). Require `<!-- delta: ... -->` and `<!-- consumed: ... -->` trailers.
6. Validate consumed list (input-set + trace cross-check). Reject if hallucinated; fall back to grep pruning.
7. Normalize, byte-compare. Identical → skip write, bump `no_change_streak`. Differs → write, reset `no_change_streak`. Reset `strict_audit_active` only on (valid non-empty consumed AND diff > 10 chars) — decoupled from failure resets.
8. Under-update guard: `no_change_streak ≥ 10` AND ≥10 unsynced entries → set `strict_audit_active = true` for next synth.
9. Prune by consumed uuid list. Cap active files at 50 entries; overflow oldest → archive. Archives rotate yearly at 5 000 entries.
10. On hard failure: bump `consecutive_failures`. Don't touch profile.md. Don't prune. Don't rename legacy.
11. On success: set `last_successful_synth`, reset `consecutive_failures=0`, atomic-write `.synth-state.json` + rotate `.bak`. Do NOT auto-reset `strict_audit_active` here — only meaningful candidate absorption clears it.
12. Release lock (PID-verified).

**`unapplied_gaps` treatment:** flag any recurring `pck_gap` from `unapplied_gaps` as high-priority in `## Recurring Teaching Gaps` — AI logged the corrective move but never followed through. Outweighs raw frequency.

**Legacy migration (one-time):** if `~/.no-vibe/profile.json`, `mistakes.json`, `ai-notes.json` exist from older version, fold content into first synth as extra evidence. **Rename to `*.legacy.json` ONLY after synth write succeeds.** If synth fails, leave legacy files intact for retry. If synth returns `no-change` on non-empty legacy payload → abort migration, set `migration_pending: true` in `.synth-state.json`; next session retries with stricter prompt.

Goal: global `profile.md` stays compact, regression-free, genuinely useful as cross-project teaching context — not a log of every event.
