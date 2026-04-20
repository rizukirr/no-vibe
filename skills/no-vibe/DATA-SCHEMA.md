---
name: no-vibe-data-schema
description: Data contracts for learner tracking at project and global levels
---

# no-vibe — Data Schema

Data lives at two levels. Read this before writing any data file.

## Implementation status (spec vs runtime)

This schema is dense — it describes atomic writes, per-project locks, uuid minting, consumed-list validation with trace cross-checks, `.synth-state.json` bookkeeping, cursor lifecycle, strict-audit telemetry, and more. **Most of it is spec, not runtime.**

**What the plugin actually implements today:**
- `.no-vibe/active` marker detection
- Write guard (`hooks/block-writes.sh` for Claude, `.opencode/plugins/no-vibe.js` for OpenCode, instruction-based soft-block for Codex/Gemini via skill + `GEMINI.md`)
- Status line (`hooks/status.sh`)
- Command docs (`commands/`, `.opencode/commands/`, `.gemini/commands/`)

**What is `[future-runtime]` and currently performed via AI discipline + Edit tool:**
- All JSON writes (no tmp+rename atomicity — AI uses the Edit tool, same risk as any text file)
- UUID minting (spec says "runtime mints" but no runtime exists; AI must generate `<prefix>-<unix-ms>-<counter>` honestly at append — an honor-system approximation)
- Per-project lock on `.no-vibe/data/.lock` (no runtime to hold it)
- Global `.profile.lock` with two-tier PID protocol
- `.synth-state.json` + `.bak` rotation
- Consumed-list validation (input-set + trace cross-check)
- Size caps + archive rotation
- Revision_id atomic coupling with session.md edits

Fields and procedures marked `[future-runtime]` in this document describe the target design. When implementing the plugin runtime, these are the specs to encode. In the meantime, AI should follow the disciplines as best-effort — the spec is still load-bearing for correctness even when not enforced.

Tests (`tests/test_block_writes.sh`, `tests/test_status.sh`, `tests/test_opencode_plugin.mjs`) cover only what's implemented today. New runtime features will need matching tests.

## Two-Tier Architecture

**Global (`~/.no-vibe/`)** — one file. AI's synthesized meta-model of the learner, spanning all projects. Improves *how* AI teaches this user, not *what* was taught:

```
~/.no-vibe/
├── profile.md              # Free-form prose. Active learner-level signals only. Loaded into Phase 1a
├── profile.archive.md      # Superseded/contradicted lines. NEVER loaded into teaching context — forensic only
├── .synth-state.json       # Cross-session synth bookkeeping (tiny, not loaded into context)
├── .synth-state.json.bak   # Previous successful state (rotation on atomic write)
└── .profile.lock           # Transient lockfile during synth (auto-removed)
```

**Project (`.no-vibe/data/`)** — raw, append-only logs for this codebase:

```
.no-vibe/data/
├── mistakes.json           # Teaching-gap entries from this project
├── mistakes.archive.json   # Pruned-out entries (overflow, resolved, already-promoted)
├── ai-notes.json           # User-driven AI notes from this project
├── ai-notes.archive.json   # Superseded / pruned ai-notes
└── sessions/
    └── <topic-slug>.json
```

No operational global JSON. Cross-project aggregation lives as prose in `profile.md`, written by the synth step (below). The two dotfiles under `~/.no-vibe/` are synth bookkeeping only — never loaded into teaching context.

**Read order:** global `profile.md` first (meta-model) → project files (session context).
**Write order:** project append first (raw evidence) → global synth (conditional, see trigger rules).

---

## Global Level — `~/.no-vibe/profile.md`

Free-form Markdown. AI's meta-model of the learner. **Full-rewrite, not append-only** — the synth step emits the whole file each time.

### Purpose filter

Every line in `profile.md` must answer yes to: **"Would I want AI to know this next time the user opens a totally different project?"**

In: teaching style, cross-domain skill calibration, recurring AI blind spots, stable preferences, directive rules.
Out: lesson content, layer-level mistakes, project-local facts, session progress.

### Required sections

```markdown
## Skill Levels
- <topic-or-lang>: <new|struggling|developing|comfortable|strong> (n projects, last: YYYY-MM-DD)

## Learning Patterns
<prose — how the user learns: concrete vs abstract, fast vs slow, what scaffolding helps>

## Recurring Teaching Gaps
<top 3 pck_gap patterns seen across projects, ranked by unapplied-rate >30%. A pck_gap
must have appeared in ≥3 sessions AND its unapplied occurrences must exceed 30% of its
total occurrences before it qualifies. Mark any in current session's unapplied_gaps
as "high priority — gap_action logged but never followed through".

If zero pck_gaps qualify, write the explicit placeholder:

  _No recurring teaching gap yet (fewer than 3 sessions, or all gaps under 30%
  unapplied-rate)._

Never leave this section empty — empty reads ambiguously as "section missing" to
downstream LLM context loading.>

## User Preferences
- <kebab-case tag>: <one-line human expansion> (source: kind=preference|request, n projects)

## AI Directives
- <kebab-case tag>: <one-line human expansion> (source: kind=correction|complaint, n projects)

## Cross-Project Observations
<free-form prose synthesizing patterns across codebases. Skill transfers, weak domains,
learning velocity trends. Keep concise — no project-specific anecdotes>
```

Contradicted lines are never kept inline in `profile.md` — they move to the sibling `profile.archive.md` (see rule 5). This keeps `profile.md` containing only current truth; Phase 1a loads only the active file, eliminating the risk of the LLM treating superseded guidance as live.

### Size cap

~200 lines. When exceeded, evict lowest-evidence lines. Eviction priority (lowest evidence first):

1. Soft lines (evidence count < 2) **AND** age ≥ 3 synths (age = synths since first added)
2. Soft lines count < 2 but age < 3 synths → **protected** (prevent thrash: new-but-valuable lines need time to accumulate evidence)
3. Hard lines (count ≥ 3) → never evicted by size cap. Only contradiction can remove them.

### Evidence tagging

Every line ends with an evidence tag: `(n projects, last: YYYY-MM-DD, age: S)` where `n` = project count, `last` = last-seen date, `age` = synth count since this line was first added. Synth increments `age` on unchanged hard lines, not on paraphrasing.

**Tag parsing tolerance with historical carry-forward.** The tag format is LLM-emitted Markdown and fragile.

1. If individual fields are missing (`age:`, `n`, or `last:`): default missing → `age: 1`, `n: 1`, `last: today`.
2. If the **entire tag is absent** (hand-edited line or dropped by LLM): before defaulting, attempt historical carry-forward — scan the immediate previous `profile.md` snapshot (one-synth-ago) for an **exact-string match after normalization**. Normalization rules (applied to both sides before comparison, deterministic):
   - Strip any trailing tag (everything after the last ` (n ` token).
   - Trim leading/trailing whitespace.
   - Collapse internal whitespace runs (multiple spaces/tabs) to a single space.
   - Lowercase.
   - Strip trailing punctuation (`.`, `!`, `?`).
   
   If a normalized line matches, carry its tag values forward. **Do NOT use semantic/fuzzy matching** — LLM judgment of "same meaning" is unreliable. The normalization rules above are conservative but tolerant of cosmetic reformatting (a rewritten line with extra spacing or trailing period still matches). If no exact-normalized match → default to `(n=1, last=today, age=1)`.
3. **Text-changed-tag-intact case (user manual edit).** If the tag is well-formed but the line text differs from last known state, preserve the tag values as-is — user rewording shouldn't reset age/n counters. Only treat as "new line" when the tag itself is absent or malformed.
4. Never reject a line for a malformed tag.

### Canonical wording lock

Hard lines (n ≥ 3) are **verbatim-protected**. Synth must NOT rephrase, shorten, or reword them. Rule on the synth prompt: "Hard lines in current profile.md are frozen — copy them byte-for-byte. Only evidence tags update. If new evidence contradicts a hard line, append a new line with `— supersedes: <hard-line-verbatim>` rather than editing the hard line."

This kills the "wording drift → broken semantic-match → duplicate re-addition" oscillation. Over many synths, canonical wording is stable; only evidence tags and supersede notes move.

**Manual-edit escape hatch.** The user may hand-edit `~/.no-vibe/profile.md` at any time between sessions (fix bad wording, prune stale prose, reword a hard line). The synth respects manual edits: on next run, it reads the file as-is, treats any modified line's tag as the canonical state, and does not attempt to "restore" the prior wording. No special flag required — because synth is full-rewrite and the prompt says "copy hard lines byte-for-byte," a manually edited hard line simply becomes the new canonical version. This is intentional: the lock is against LLM drift, not against user intent.

### Synth step — full-rewrite pattern

Borrowed from DeepTutor's memory consolidation. The LLM receives the current `profile.md` plus new project entries and emits a merged whole — or returns unchanged.

**Trigger (either/or):**
- Session end (complete or early close)
- Project log has ≥3 new learner-level candidate entries since last synth

**Candidate filter** — before invoking synth, build the candidate list by:

1. Reading new project entries from `mistakes.json` + `ai-notes.json`.
2. **Excluding** any uuid present in `pruning_cursor.<project>.mistakes_synced_ids` or `ainotes_synced_ids` — these are already consumed, mid-archival, or fully archived. Including them would race-surface a half-processed entry as a fresh candidate.
3. **Excluding** entries with `resolved_at != null`, `superseded != null`, or (for mistakes.json) entries whose `misconception_id` appears as resolved in any earlier archive entry.
4. Applying the purpose filter ("would I want this in a totally different project?").

If zero candidates survive → skip synth entirely, no file write.

**Synth prompt (internal):**
```
You are rewriting ~/.no-vibe/profile.md.

## Current profile.md
<existing file contents, or "(empty)">

## New candidate evidence from project <name>
- mistakes (learner-level only, resolved entries excluded): <filtered entries>
- ai-notes (learner-level only, superseded entries excluded): <filtered entries>
- session outcome: <skill-level delta from errors_this_session>
- unapplied pck_gap categories from this session: <list of pck_gap values derived from entries where applied=false; map misconception_id → pck_gap first; raw misconception_ids are project-local and must not reach global>


Rewrite the full profile.md. Apply rules in order:

1. Hard lines (evidence count n ≥ 3) are FROZEN. Copy byte-for-byte.
   Only the evidence tag may change (increment n, bump last date, bump age).
2. Exact-match existing line (any n) → keep, bump evidence tag
3. Semantic-match existing soft line → keep the existing wording, bump evidence tag.
   Do NOT add a near-duplicate with different phrasing.
4. Refines existing soft line → edit the existing soft line in place.
5. Contradicts existing line (hard OR soft) → MOVE the existing line OUT of
   profile.md and INTO sibling file `~/.no-vibe/profile.archive.md` (append,
   prefixed `[superseded YYYY-MM-DD from <section>]`). Append the new line in
   the correct active section of profile.md. Phase 1a never loads the archive;
   the active file contains only current truth.
6. Novel and passes the purpose filter → append to correct section.
7. No new learner-level signal at all → return the file unchanged.

Touch only lines where new evidence warrants change. Do not rephrase existing
prose. If nothing changed, return the file unchanged verbatim.

At the end of your output, append exactly two lines:
<!-- delta: <one-line summary of what changed, or "no-change: <why>"> -->
<!-- consumed: <comma-separated list of candidate ids that were absorbed, including tag-bump absorptions; empty list if none> -->
```

Candidate ids are passed into the prompt as the deterministic uuids from each entry's `id` field (e.g. `m-1713542410234-0001`). The `consumed` list is the ground truth for pruning — do NOT rely on grepping the new file contents (tag-bump absorptions change evidence tags only, so grep misses them).

**Consumed-list validation (anti-hallucination) — two layers.**

**Layer 1: input-set validation.** Every uuid in `<!-- consumed: ... -->` must be in the candidate uuid set originally passed into the synth prompt.
- Any uuid NOT in input set → **reject entire consumed marker** (all-or-nothing), bump `consumed_validation_failures` in `.synth-state.json`, fall back to grep-based pruning.
- Three consecutive failures → inject stronger prompt directive demanding input-set-only uuids.

**Layer 2: trace cross-check.** Passing layer 1 isn't enough — LLM may claim consumption of an in-set uuid it never actually absorbed. For each uuid that survived layer 1:
- Search the new `profile.md` for any line whose content semantically covers the candidate entry's core signal (exact-substring match of `gap_action` keywords or `directive` for ai-notes, case-insensitive, whitespace-normalized).
- OR check whether any existing line's evidence tag was bumped this synth (indicating tag-bump absorption).
- If neither → mark uuid as "claimed-without-trace", **do NOT archive** this entry. Keep it in the active file. Log to `.synth-state.json.consumed_trace_misses`.
- Streak ≥ 3 consecutive syntheses with trace misses → inject prompt reinforcement explaining the trace requirement.

Without layer 2, an LLM could list a valid uuid in consumed while never mentioning its content in profile.md → prune moves the real entry to archive → silent data loss. Layer 2 makes the claim falsifiable.

**Write guard:** normalize both sides (trim trailing whitespace per line, unify line endings to `\n`, strip both trailing `<!-- delta: ... -->` and `<!-- consumed: ... -->` markers) before byte-compare. If normalized output identical → skip write. The markers are parsed for telemetry / pruning then stripped from the written file.

**Delta marker absence is NOT a failure.** If the output is a semantically-valid `profile.md` diff but the LLM forgot to emit the `<!-- delta: ... -->` trailer → write still succeeds, just log a warning and synthesize a generic delta (`"delta: auto-generated (marker missing)"`). Same for a missing `<!-- consumed: ... -->` marker — fall back to conservative grep-based pruning. Only count as hard failure: empty output, non-parseable markdown structure (e.g., dropped required section headers), or exception during LLM call.

**Consumed-marker streak watchdog.** `.synth-state.json` tracks `missing_consumed_marker_streak`. Incremented each synth that omits the trailer. Reset on emission. After 3 consecutive omissions → inject an explicit reinforcement line into the synth prompt (`"You have omitted the <!-- consumed: ... --> trailer 3 times in a row. Emit it on this run without fail — pruning depends on it."`). Without this watchdog, silent fallback-to-grep would let fix-1 protection quietly degrade and zombies would return.

**Under-update detection:** `.synth-state.json` tracks `no_change_streak`. If the last 10 synths all reported `no-change` while project logs show ≥10 new candidate entries accumulated, flag the next synth with a stronger prompt: `"Previous 10 synths all returned no-change despite new evidence. Audit aggressively — is anything truly learner-level being missed?"` Prevents silent stagnation.

**Concurrency lock:** before synth, acquire `~/.no-vibe/.profile.lock` (writes `{pid: N, started: ISO-timestamp}`). Two-tier reclamation rule:

1. **Dead PID → immediate reclaim.** Check if the lock's PID is still running. If not → reclaim without waiting.
2. **Live PID, age ≥ 5 minutes → reclaim.** 5-minute ceiling covers legitimately slow synths (large profile.md + many candidates + slow LLM) without collision risk in practice.
3. **Live PID, age < 5 minutes → skip synth** (another session actively running).

Release lock on completion or error (`finally` semantics). **Release is PID-verified**: before `unlink`ing `.profile.lock`, read the lock file and confirm the stored PID matches the current process. If it doesn't (the lock was stolen by another process after the 5-min ceiling), skip the release — the new owner will clean it up. Without PID-verified release, a slow synth that got its lock reclaimed could unlink the replacement owner's lock, allowing a third writer to race in.

PID-liveness check is platform-dependent: POSIX → `kill -0 <pid>`; Windows → tasklist lookup or similar. Plugin implementation chooses; spec requires the two-tier behavior plus PID-verified release, not a specific syscall.

**Fallback & failure tracking:** synth failures (empty output, parse error, missing delta marker, LLM error) are tracked in **`~/.no-vibe/.synth-state.json`**, not in the session JSON. Schema:

```json
{
  "last_successful_synth": "2026-04-19T14:32:10Z",
  "consecutive_failures": 0,
  "no_change_streak": 0,
  "missing_consumed_marker_streak": 0,
  "strict_audit_active": false,
  "migration_pending": false,
  "last_project_synced": "numc",
  "pruning_cursor": {
    "numc": {
      "mistakes_synced_ids": ["m-a3f5e2d1", "m-4c8e1f0b"],
      "ainotes_synced_ids": ["a-b7c2f8e4"]
    }
  }
}
```

Pruning cursor tracks **uuids**, not filenames or indices. Rationale: (1) indices shift if new entries are appended between read and prune; (2) filenames rotate at year boundaries and would desync. Uuid-based cursor survives both scenarios — at prune time, resolve each uuid against whichever file currently holds it (active or archive). If the uuid isn't found in either → candidate was already archived by a prior run; skip silently.

**Cursor lifetime — ephemeral, not cumulative.** The cursor only holds uuids that are *in-flight for the current synth*: consumed by the latest prompt but not yet moved to archive. On successful prune-to-archive, the uuid is removed from the cursor. Steady-state: cursor is empty. Archive files are the authoritative history of what was consumed.

This resolves the apparent contradiction with the double-corruption recovery path: recovery reconstructs "what was in-flight at crash time" (usually nothing), not the full history. Full history is in the archives. The cursor is a transient in-flight buffer, sized O(1 synth) not O(lifetime).

After 3 consecutive failures, skip synth this session **and** the next session. Reset only on success. Protects global state from perpetual-failure drift that session-local counters would miss.

**Atomic writes for `.synth-state.json`.** Always write via `tmp + rename`:
1. Write new state to `~/.no-vibe/.synth-state.json.tmp`.
2. `fsync` the tmp file.
3. `rename` to `.synth-state.json` (atomic on POSIX and modern Windows).
4. Keep `~/.no-vibe/.synth-state.json.bak` — copy of the previous successful state. Rotate on every successful write.

On startup, if `.synth-state.json` is missing or parse-fails → fall back to `.synth-state.json.bak`. If backup also fails → initialize fresh empty state:

```json
{"last_successful_synth":null,"consecutive_failures":0,"no_change_streak":0,"missing_consumed_marker_streak":0,"consumed_validation_failures":0,"strict_audit_active":false,"migration_pending":false,"last_project_synced":null,"pruning_cursor":{}}
```

Because the cursor is ephemeral (in-flight for one synth only, always empty at steady state), losing it is cheap: at most one synth's worth of candidates may be re-promoted. The next synth's candidate filter still protects against duplicate promotion because:

1. Candidates with `resolved_at` set are excluded → already-resolved gaps skip.
2. Candidates whose semantic content already matches a hard line in `profile.md` hit rule 2 of the synth (exact/semantic match → bump evidence tag, not append).
3. The synth prompt itself enforces "no duplicate lines; bump evidence if already present."

So a cursor wipe mostly causes wasted synth cycles (tag bumps instead of proper archival), not file-level duplicate lines. Scan-archive recovery is **not needed** — it was an overbuilt defense against a model where cursor was cumulative. Under the ephemeral-cursor model the damage surface is O(one synth), not O(full history).

**Pruning after successful synth:**

1. For each candidate entry that made it into the new `profile.md` (grep the filtered candidates against the new file's content) → move the project-level source entry to `mistakes.archive.json` or `ai-notes.archive.json`.
2. Update `pruning_cursor` in `.synth-state.json` with the new index bound for this project.
3. Entries that did NOT pass the purpose filter but are ≥6 months old → also archive (stale project-local noise).
4. Cap active project files at 50 entries. Overflow → archive oldest.

Archive files are not loaded during Phase 1a, audit, or synth. They exist only for forensic review.

**Archive rotation.** Archive files have no hard size cap — disk is cheap, nothing reads them. However, per-file soft cap: at 5 000 entries, roll to `mistakes.archive.<YYYY>.json` / `ai-notes.archive.<YYYY>.json` (year-stamped) and reset the active archive. Old archives remain on disk, frozen.

**Strict-audit flag reset — game-proofed, decoupled from failures.** `strict_audit_active` resets ONLY via the meaningful-differ-write path:

- `<!-- consumed: ... -->` validated non-empty AND trace-checked AND byte-diff exceeds 10 chars excluding markers + whitespace. Real candidate absorption. Sets `strict_audit_active = false`.

**Strict audit does NOT reset on `consecutive_failures` clearing.** Rationale: under-update signal is independent of LLM error rate. A run of failures followed by a trivial no-change success does not mean the laziness has been addressed — only that the LLM eventually produced parseable output. Bundling the reset would let failure storms erase legitimate laziness flags.

Tracking fields in `.synth-state.json`:
- `strict_audit_active: bool` — is the flag on.
- `strict_triggered_at: ISO-timestamp | null` — when it was raised. Useful for telemetry and for manual audit ("strict mode has been on for 3 sessions — something is stuck").

If strict mode persists suspiciously long (≥5 consecutive synths) → inject a diagnostic line into the synth prompt asking the LLM to explain why it has not consumed candidates. Surfaces the underlying issue to the user in telemetry.

### Skill level computation (feeds synth input, not stored separately)

Per session, compute new skill level from `gaps_this_session`:
- `gaps_this_session == 0` → move up one level
- `gaps_this_session <= 1 && layers_completed >= 5` → move up one level
- `gaps_this_session >= 3` → move down one level
- Otherwise → stay

Pass the delta (if any) into the synth prompt as "session outcome". Progression: `new` → `struggling` → `developing` → `comfortable` → `strong`.

---

## Project Level (`.no-vibe/data/`)

### mistakes.json — Teaching-Gap Log

Append-only. Each entry = a teaching failure AI observed, not a learner flaw. Grounded in Brown & Burton bug-libraries (`misconception_id`), Shulman PCK (`pck_gap`), Sweller CLT (`load_mismatch`), Schön reflection-on-action (`reflection_window`), Black & Wiliam formative feedback (`gap_action`).

```json
[
  {
    "id": "m-a3f5e2d1",
    "user_mistake": "used len(arr)-1 as loop bound",
    "misconception_id": "fencepost-off-by-one",
    "pck_gap": "buried-key-rule",
    "load_mismatch": "over-explained",
    "gap_action": "lead with fencepost rule as 1-line invariant before examples",
    "reflection_window": 3,
    "applied": false,
    "retry_count": 0,
    "resolved_at": null,
    "correct_uses": [],
    "topic": "tensor indexing",
    "layer": 3,
    "revision_id_at_creation": 0,
    "created_at": "2026-04-19T14:32:10Z"
  }
]
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Deterministic unique id: `m-<unix-ms>-<counter>` where counter is a monotonic integer for the lifetime of this file (starts at 0 on file creation, increments on every append, never resets). Example `m-1713542410234-47`. Never generated by the LLM — the plugin runtime mints it on append. Collision-free within a project. No timezone ambiguity; no midnight edge cases |
| `created_at` | `string` | ISO-8601 timestamp of creation. Authoritative ordering for audit tie-break ("newest wins" on conflicting `gap_action`s) |
| `user_mistake` | `string` | One-line factual description |
| `misconception_id` | `string` | Kebab-case bug rule. Reusable across entries |
| `pck_gap` | `string` | Enum: `buried-key-rule`, `missing-analogy`, `wrong-sequencing`, `no-prereq-check`, `jargon-overload`, `jumped-abstraction`, `ambiguous-naming`, `other` |
| `load_mismatch` | `string` | `over-explained`, `under-scaffolded`, `correct` |
| `gap_action` | `string` | Imperative corrective move. May be appended ` — superseded: <reason>` |
| `reflection_window` | `number` | Prior AI turns scanned (typically 2–3) |
| `applied` | `boolean` | Flipped true when next reply embodies `gap_action` |
| `retry_count` | `number` | Bumped when same `misconception_id` + `pck_gap` recurs with `applied=true` (gap_action failed to stick) |
| `correct_uses` | `[{layer: number, date: string}]` | Appended by Phase 4 review whenever the same `misconception_id` appears **correctly** in the user's code (not as a mistake). Deterministic signal for auto-resolving |
| `resolved_at` | `string \| null` | ISO date set automatically when `applied=true` AND `len(correct_uses) >= 2`. Resolved entries are excluded from pre-turn audit + synth candidates + Phase 1a scaffolding decisions. Never set manually — the counting rule drives it |
| `topic` | `string` | Session topic |
| `layer` | `number` | Curriculum layer where mistake occurred (pre-revision absolute number at time of creation) |
| `revision_id_at_creation` | `number` | The session's `revision_id` at the moment this entry was created. Used to shift the Phase 4 resolution-detection window when the curriculum is later revised (see SKILL.md "Resolution detection"). Without this, layer-insertion revisions would drift the "same conceptual territory" window wrong |

#### No-regression rules (pre-append)

Before appending, scan existing entries:

| Match condition | Action |
|---|---|
| Same `misconception_id` + same `pck_gap` + `applied=true` | **Regression.** Update existing entry: set `applied=false`, bump `retry_count`, overwrite `gap_action` with new, harder corrective move. Do NOT append duplicate |
| Same `misconception_id` still `applied=false` | AI never followed through. Update existing entry in place (strengthen `gap_action`). Do NOT stack duplicate |
| Same `pck_gap`, similar `gap_action` wording, recent | Merge evidence. Do NOT add near-duplicate. Update `gap_action` in place if new wording is sharper |
| Same `misconception_id`, different `pck_gap`, new `gap_action` contradicts old `gap_action` semantically | Diagnosis shifted. Mark old: `applied=true`, append ` — superseded: new diagnosis is <pck_gap>` to its `gap_action`. Append new entry. Audit: one active entry per `misconception_id` by design after this rule fires |
| Same `misconception_id`, different `pck_gap`, **clearly** compatible `gap_action`s | **Merge at append time**, do NOT dual-append. Update existing entry: combine `gap_action`s into one imperative sentence ("lead with invariant AND give a concrete counterexample"), update `pck_gap` to the newer diagnosis if it's more specific. Only take this branch when the new `gap_action` is *clearly* a compatible refinement (same teaching stance, sharper wording). **When in doubt, default to the contradiction branch (supersede old, append new) — it is cheaper to over-supersede than to silently merge distinct corrections into one watered-down directive** |
| Otherwise | Append |

### ai-notes.json — User-Driven AI Notes

Append-only. Captures correction/feedback/request/complaint/preference signals.

```json
[
  {
    "id": "a-b7c2f8e4",
    "kind": "preference",
    "category": "output-style",
    "summary": "user prefers terse responses with no trailing summary",
    "trigger": null,
    "directive": "skip end-of-turn recap unless asked",
    "created_at": "2026-04-19T14:32:10Z"
  }
]
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `id` | `string` | Deterministic id format `a-<unix-ms>-<counter>` minted by the plugin runtime on append (never by the LLM). See mistakes.json `id` field for full format and collision semantics |
| `created_at` | `string` | ISO-8601 timestamp of creation. Authoritative ordering |
| `kind` | `string` | `correction`, `feedback`, `request`, `complaint`, `preference` |
| `category` | `string` | Kebab-case, reusable |
| `summary` | `string` | One-line paraphrase of user's statement |
| `trigger` | `string \| null` | What AI did that caused the note. `null` for pure preference/request |
| `directive` | `string` | What AI should do differently next time |

#### Kind semantics

- `correction` — user said "no, don't", "stop", "that's wrong"
- `feedback` — neutral/positive evaluative ("this was better", "keep doing X")
- `request` — new instruction ("from now on…", "always…")
- `complaint` — recurring frustration
- `preference` — stated style without a specific trigger

#### No-regression rules (pre-append)

| Match condition | Action |
|---|---|
| Same `(kind, category, directive)` text | **Skip.** User said same thing twice |
| Same `category`, opposite `directive` | **Contradiction.** Move old entry to `ai-notes.archive.json` with added `"superseded": "YYYY-MM-DD"` field. Append new to active file. Keeps active file lean and eliminates the "synth forgot to filter superseded" regression vector |
| Same `category`, more specific `directive` | **Refinement.** Update old `directive` in place. Do NOT append |
| Otherwise | Append |

### sessions/\<topic-slug\>.json — Session Snapshot

One file per session. Created at Phase 1c. Updated at every phase transition. Slug: lowercase topic, spaces→hyphens, strip non-alphanumeric except hyphens, max 50 chars.

```json
{
  "topic": "Build a Linear Layer",
  "mode": "concept",
  "status": "in_progress",
  "started": "2026-04-12",
  "layers_total": 7,
  "layers_completed": 0,
  "current_phase": "phase1c",
  "current_layer": 0,
  "revision_id": 0,
  "errors_this_session": 0,
  "entries_this_session": 0,
  "unapplied_gaps": [],
  "refs": ["pytorch"]
}
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `topic` | `string` | Human-readable |
| `mode` | `string` | `concept`, `skill`, `debug` |
| `status` | `string` | `in_progress` → `completed` or `abandoned` |
| `started` | `string` | ISO date |
| `layers_total` | `number` | Curriculum length |
| `layers_completed` | `number` | |
| `current_phase` | `string` | `phase1a`..`phase6` |
| `current_layer` | `number` | 1-based, 0 = not started |
| `revision_id` | `number` | Monotonic counter. Auto-incremented whenever `.no-vibe/session.md` is rewritten with a layer-structure change (see "Atomic revision" note below). Session.md rewrite + revision_id bump are a single operation — never ordered separately |
| `errors_this_session` | `number` | Count of **user errors** observed this session. Incremented on EVERY error, whether it resulted in a new `mistakes.json` append or an update to an existing entry (regression-update path). Feeds skill-level delta |
| `entries_this_session` | `number` | Count of **new mistakes.json appends** this session (excludes regression-updates to existing entries). Telemetry only. Legacy key `gaps_this_session` / `mistakes_this_session` accepted on reads — treat as `entries_this_session` |
| `unapplied_gaps` | `string[]` | `pck_gap` values (not `misconception_id` — those are project-local) from this session's entries where `applied=false` at session close. Passed to synth prompt so global profile.md flags them as high-priority blind spots |
| `refs` | `string[]` | Reference project names |

Synth failure tracking has moved to `~/.no-vibe/.synth-state.json` (survives across sessions — session-local counters missed perpetual-failure drift).

#### Zero-regression invariants (pre-write validation)

- `current_layer` may only **decrease** if `revision_id` is higher than the previously stored value. Pure decrement without a revision bump → reject write.
- `status` never flips `completed` → `in_progress`. Reject.
- `layers_completed` never decreases. Reject.
- `revision_id` is monotonic non-decreasing. Reject on decrement.

#### Atomic revision (session.md + revision_id)

`.no-vibe/session.md` and the session JSON's `revision_id` are updated together as a single atomic operation whenever the curriculum's layer structure changes (step inserted, step collapsed, pivot). Procedure:

1. Edit `.no-vibe/session.md` to new curriculum.
2. In the **same write batch**, bump `revision_id += 1` in the session JSON.
3. Announce the revision in chat.

Current reality: the plugin surfaces (`.opencode/plugins/no-vibe.js`, `hooks/block-writes.sh`, Gemini soft block) do NOT implement automatic coupling — they only enforce the write guard. A plugin-layer auto-coupling implementation is a `[future-runtime]` goal. Until it exists, coupling is an **AI-discipline rule**:

- Whenever the AI rewrites `.no-vibe/session.md` with a layer-structure change, the same response turn must also write an updated session JSON with `revision_id` incremented.
- If the AI forgets, the zero-regression invariant catches the next `current_layer` decrement as a rejected write. The AI then sees the rejection, bumps `revision_id`, and retries. One-turn round trip, not a data regression.
- Rejection is the correct guard here — breaking UX on a forgotten bump is better than accepting a silent curriculum change that breaks the invariant's meaning.

The previous spec claimed "plugin layer auto-bumps" and "soft-guard auto-bump on detection." Neither exists in code. Discipline + rejection is the honest current design until `[future-runtime]` coupling ships.

#### Atomic writes + per-project lock

Every write to any project JSON (session JSON, `mistakes.json`, `ai-notes.json`, archives) uses tmp + rename:

1. Write updated JSON to `<name>.json.tmp`
2. `fsync`
3. `rename` to `<name>.json` (atomic)

Session JSON writes are frequent (every user error increments counters). Without atomicity, a crash mid-write on a high-churn session could corrupt the counter state and crash-restart the pre-turn audit.

**Per-project concurrency lock.** Two concurrent sessions in the same project (two terminals, same codebase) would race on `mistakes.json` / `ai-notes.json` appends. Acquire `.no-vibe/data/.lock` before any mutation, with the same two-tier PID-verified protocol as `~/.no-vibe/.profile.lock`:

- Dead PID → immediate reclaim.
- Live PID age < 5 min → wait + retry with 100ms backoff up to 30s. Project-level mutations are fast (single append), so 5-min ceiling almost never triggers.
- Live PID age ≥ 5 min → reclaim.
- Release PID-verified.

Reconstruction: session JSON is reconstructable from `.no-vibe/session.md` (partial — curriculum only, counters reset; mark `reconstructed: true` so synth treats the outcome as null-signal for skill delta).

---

## Initializing Data Files

**Global (`~/.no-vibe/`):**
- `profile.md` → empty file
- `profile.archive.md` → empty file
- `.synth-state.json` → `{"last_successful_synth":null,"consecutive_failures":0,"no_change_streak":0,"missing_consumed_marker_streak":0,"strict_audit_active":false,"migration_pending":false,"last_project_synced":null,"pruning_cursor":{}}`
- `.synth-state.json.bak` → created on first successful write
- `.profile.lock` → does not exist until a synth is running

**Project (`.no-vibe/data/`):**
- `mistakes.json` → `[]`
- `mistakes.archive.json` → `[]`
- `ai-notes.json` → `[]`
- `ai-notes.archive.json` → `[]`
- Session files → created fresh per session at Phase 1c

If a file is missing when about to write, create it with the default above first.

## Legacy tolerance & migration

Old installs may have `~/.no-vibe/profile.json`, `mistakes.json`, `ai-notes.json`. On first run under this schema:

1. Detect legacy files. Read into memory.
2. Fold legacy content into the candidate-evidence block of the **first** synth of `profile.md`.
3. **Rename legacy files to `*.legacy.json` ONLY after the synth write succeeds** (write-ordering rule). If synth fails, leave legacy files untouched so the next session can retry. Prevents data loss when synth is flaky on the migration boundary.
4. If synth returns `no-change` on a non-empty legacy payload → abort migration, keep legacy files intact, flag in `.synth-state.json` with `"migration_pending": true`. Next session retries with a stricter "these are migration candidates, audit aggressively" prompt.

Legacy project-level entries missing `retry_count`, `applied`, `resolved_at`, or `misconception_id` are tolerated. Treat missing `applied` as `true`, missing `retry_count` as `0`, missing `resolved_at` as `null`, missing `misconception_id` as the old `category` field if present.
