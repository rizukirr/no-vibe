# no-vibe — Design Spec

**Date:** 2026-04-09
**Author:** rizukirr (with brainstorming assist)
**Status:** Draft for review

## 1. Purpose

`no-vibe` is a Claude Code plugin that prevents AI from writing code into the user's project files and instead guides the user through writing it themselves, top-down from a high-level API to its foundations. The name is a deliberate stance against "vibe coding" — letting AI generate code you don't understand. The plugin's whole point is to force the user to do the work and build real intuition.

The plugin is invoked while the user is working inside a real project. They want to learn something — how a library works, how to build a feature, how to debug an issue — and they want to do it by writing the code themselves with AI as a tutor, not a generator.

## 2. Goals & Non-Goals

### Goals

- Force AI to never write code into project files (enforced by hook, not just instructions)
- Allow AI to show code in chat — the user types it themselves
- Guide the user through a structured teaching cycle: minimal skeleton → add layers one at a time → synthesize → tease advanced topics
- Ground every example in real reference projects (cloned via `git clone --depth 1`) when available
- Adapt the lesson curriculum on the fly based on the user's actual progress
- Keep pacing trust-based — user advances by saying "next", no proof required
- Preserve the user's main Claude session context (no sub-agents)
- Save lesson summaries to a scratch directory the user can revisit

### Non-Goals

- Not a code generator. AI must never produce production-ready code blocks for the user to copy verbatim into their project.
- Not a standalone learning platform with curated courses. Lessons are generated per-request, grounded in the user's actual project.
- Not a replacement for documentation. References are pointers, not summaries.
- Not an enforcement mechanism for *correctness*. The plugin enforces *process* (no-code-in-files, layered teaching), not whether the user's code is correct.
- Not a sub-agent. Runs in the user's main session so it inherits project context.

## 3. User-Visible Surface

### Plugin name

`no-vibe`

### Command

`/no-vibe` with four invocation forms:

| Invocation | Behavior |
|---|---|
| `/no-vibe <topic>` | One-shot lesson. Marker created, lesson runs full cycle, marker removed when done. |
| `/no-vibe on` | Persistent mode. Marker created and stays. Every subsequent message is treated as a learning request until `/no-vibe off`. |
| `/no-vibe off` | Removes marker. If a lesson is mid-flight, run synthesis phase first to wrap it up cleanly. |
| `/no-vibe --ref <name-or-url> <topic>` | As above plus attach a reference project. URL → cloned via `git clone --depth 1` into `.no-vibe/refs/<name>/`. Bare name → use `.no-vibe/refs/<name>/` if it already exists. Multiple `--ref` flags allowed. |
| `/no-vibe --mode {concept\|skill\|debug} <topic>` | Mode selection. Default: `concept`. |

### Modes

- **concept** (default) — emphasis on understanding *why*. More prose, deeper Socratic probes, slower pacing. Best for "teach me how X works."
- **skill** — emphasis on building muscle memory. More "type this exactly", lighter probes, repetition. Best for "I want to practice writing Y."
- **debug** — starts from the user's symptom and descends toward the root cause. Best for "why does my Z behave like this?"

## 4. Architecture

### Plugin layout

Everything lives under `.claude-plugin/` to match the existing scaffold convention:

```
no-vibe/
└── .claude-plugin/
    ├── plugin.json
    ├── commands/
    │   └── no-vibe.md
    ├── skills/
    │   └── no-vibe/
    │       ├── SKILL.md
    │       └── curriculum.md
    └── hooks/
        └── block-writes.sh
```

(The implementation plan should verify this matches the Claude Code plugin convention before locking it in. The existing `instructure-mode` scaffold places `skills/` under `.claude-plugin/`, so this layout mirrors what's already there.)

### Component responsibilities

- **`commands/no-vibe.md`** — User-facing entry point. Parses invocation form (`<topic>` vs `on` vs `off`), parses `--ref` and `--mode` flags, manages the `.no-vibe/active` marker, clones reference projects, loads the skill.
- **`skills/no-vibe/SKILL.md`** — Defines the three modes, the teaching cycle rhythm, the no-code-in-files directive, the reference-grounding rule, and how to use the scratch directory. Loaded by the command.
- **`skills/no-vibe/curriculum.md`** — Reference material the skill pulls in for structured topics (e.g., common pedagogical patterns for ML, web frameworks, systems topics). Keeps SKILL.md focused on rules.
- **`hooks/block-writes.sh`** — `PreToolUse` hook. When `.no-vibe/active` exists in cwd and the tool is `Edit`/`Write`/`NotebookEdit`/`MultiEdit` and the target path is outside `<cwd>/.no-vibe/`, deny with an explanatory message.

### Runtime state

Lives in the user's project working directory under `.no-vibe/`:

```
.no-vibe/
├── active                        # marker file; presence = no-vibe mode on
├── session.md                    # current lesson's curriculum + progress
├── notes/
│   └── YYYY-MM-DD-<topic>.md     # final summaries saved per lesson
└── refs/
    ├── pytorch/                  # cloned reference projects
    └── tinygrad/
```

The marker file is the single source of truth for whether the hook should enforce. The session file is the user-visible curriculum, kept in sync as the lesson progresses. Notes are append-only. Refs are user-managed (the command clones; the user can delete).

## 5. The Teaching Cycle

The skill encodes a six-phase rhythm. Phases 2–5 form an inner loop that iterates over curriculum items.

### The runnability invariant

**Every layer must leave the user's code in a runnable state, and ideally must produce *new visible behavior* the user can verify by running it.**

This is the heartbeat of the cycle. The rhythm is:

> introduce → user types → **user runs and sees output** → user says "next"

Without runnability at every step, the user can stack four layers of code that all collapse on first run, and the whole pedagogical loop breaks. The skill enforces this when *designing* the curriculum (Phase 1c) and when *adding each layer* (Phase 3): no layer may be introduced unless it leaves the code runnable end-to-end.

**Concrete consequences:**

- Phase 2's skeleton must produce output when run (e.g., empty function + `print("linear initialized")`), not just be syntactically valid.
- Each Phase 3 layer must add behavior the user can *observe*. Adding parameters? Print them. Adding a dot product? Print the result. Adding a loop? Run it on a sample array and print what comes out.
- If a layer would naturally not produce output (e.g., refactoring for cleanliness), AI must add a temporary `print` or assertion so the user has something to verify, then optionally remove it in a later layer.
- AI's "show this code" output should always include the run command (`python linear.py`, `pytest test_linear.py::test_skeleton`, etc.) so the user knows exactly what to type.

**Why this changes the curriculum design:**

A naive curriculum might say "step 4: vectorize with numpy". But that's not runnable on its own — it presumes step 3's data is still in scope. A runnable-aware curriculum says "step 4: vectorize with numpy, then run on `np.array([1,2,3])` and print the output." Every step is a complete, executable program.

### Phase 1a — Context analysis & targeted clarification

Before asking the user anything, AI silently analyzes:

- The `/no-vibe` invocation (topic, mode, refs)
- The user's project (Read/Grep a few relevant files to infer stack, style, naming conventions, apparent skill level)
- Any attached reference project's structure (a glance at top-level directories)
- Conversation history for any prior context

From this, AI forms a working hypothesis about who the user is and what they want. Then it asks **only the clarifying questions needed to disambiguate genuine forks**. If the hypothesis is confident, AI does a brief sanity check: *"I've had a look at your project — looks like you're comfortable with numpy and have a `layers/` module. I'm guessing you want a Linear layer that fits that style, going from scratch down to matmul. Correct me if I'm wrong, otherwise I'll draft the curriculum."*

**Rule:** never ask a question you could have answered by reading the code.

### Phase 1b — Reference suggestion

If the user did not pass `--ref`, AI proposes 2–3 candidate projects with distinct pedagogical angles (e.g., production / minimal-real / pure-pedagogical). User picks; AI clones via Bash. If user already provided a ref, this phase is skipped.

### Phase 1c — Draft curriculum

AI writes `.no-vibe/session.md` with the lesson plan, grounded in the intake hypothesis and (if available) the structure of the reference code. Example:

```markdown
# Lesson: Build a Linear layer like pytorch's
Mode: concept
Refs: pytorch (torch/nn/modules/linear.py)
Started: 2026-04-09

## Curriculum
- [ ] 1. Empty function skeleton — just a callable that prints
- [ ] 2. Add weight + bias as plain lists
- [ ] 3. Plain dot product (no loops, hard-coded shapes)
- [ ] 4. Vectorize with a loop over inputs
- [ ] 5. Swap loop for numpy matmul
- [ ] 6. Compare to torch.nn.Linear — cite real source
- [ ] 7. Synthesize + advanced pointers

## Notes
(grows as lesson progresses)
```

AI presents the curriculum in chat; user approves or edits. Approval gates entry to Phase 2.

### Phase 2 — Minimal skeleton

AI shows the smallest runnable shape in chat (e.g., empty function with a print). Explains what it is and what it isn't yet. Says: *"type this into your project, run it, tell me when you're ready."*

User writes it, says "next" (or "got an error: …").

### Phase 3 — Add one layer

AI introduces exactly one new concept on top of the skeleton. Each layer addition includes:

1. The concept in prose
2. The code to add, shown in chat with clear "add this / replace that" framing
3. *Why* this layer exists
4. If `--ref` is attached: a citation to the real implementation at this same level of maturity (`file:line`, with a quoted snippet)

User writes the change, says "next".

### Phase 4 — Review

After every "next", AI uses Read on the user's file(s) and checks (a) the layer's intent is present and (b) the code is still runnable end-to-end. AI may optionally use Bash to actually execute the code itself for verification (e.g., `bash -c "cd <project> && python <file>"`) — this is a tool available to AI, not a demand for proof from the user. Three outcomes:

- **Good** — brief affirmation, advance to Phase 5.
- **Small issue** — point out the specific problem with a teaching framing (not scolding), explain *why* it matters, ask user to fix. Re-review on next "next".
- **Fundamental misunderstanding** — pause the cycle, explain the gap in prose (no code), and revise the curriculum (`.no-vibe/session.md`) to insert a prerequisite layer before continuing. Announce the revision.

**Rule (in skill):** *Before advancing from any layer, you MUST Read the file(s) the user is working in and confirm the layer's intent is present. Your job is to teach the specific concept of this layer, not to accept any code that runs.*

**Edge case:** if the user's code is *better* than what AI suggested, AI acknowledges it explicitly and keeps the user's version.

### Phase 5 — Check-in

After the review confirms the layer is good, AI asks an open check-in:

> *"Any questions about this layer? Anything you want me to expand on before we move to the next step?"*

Three outcomes:

- **User says "no, next"** → advance to the next curriculum item (loop back to Phase 3).
- **User asks a question** → AI answers in prose (no code blocks for the user to copy), as deeply as the question warrants. Then re-asks the check-in. Loop until the user is ready.
- **User asks something that warrants becoming its own lesson step** → AI offers to insert it into the curriculum (parking it for after the current step) or pivot to it now. Same branching rule as the curriculum revision triggers.

The cycle exits when the curriculum is complete. The check-in is intentionally not a quiz — the philosophy is that the user is the active party and knows their own gaps better than AI can guess. The Phase 4 review already catches code-level mistakes; Phase 5 only catches *conceptual* gaps the user themselves notices.

### Phase 6 — Synthesize & tease

When the curriculum is exhausted, AI produces:

- A **summary** of what was built, layer by layer, with the *why* of each transition
- A **mental model** — one paragraph the user can carry away
- **Advanced techniques** — 3–5 bullets pointing outward, not exhaustively explained, designed to keep curiosity alive

The synthesis is auto-saved to `.no-vibe/notes/YYYY-MM-DD-<topic>.md` and the corresponding curriculum item in `.no-vibe/session.md` is checked off.

### Curriculum revision triggers

Throughout the cycle, AI rewrites `.no-vibe/session.md` when any of these happen:

- **User struggles** → insert a prerequisite step. Announce the change with *why*.
- **User breezes through** → collapse or drop upcoming steps. Announce.
- **User asks a sideways question** → either park as a new step later or pivot the lesson entirely. AI always asks: *"park for later, or pivot now?"*
- **Reference reveals something unexpected** → insert a step. Announce.

**Every revision is (1) written to `.no-vibe/session.md`, (2) announced in chat with *why*, (3) never silent.**

## 6. Enforcement

### Hook mechanism

`hooks/block-writes.sh` is a `PreToolUse` hook registered in `plugin.json`. It receives the tool call as JSON on stdin and decides whether to allow or deny.

### Hook logic

```
1. Read JSON from stdin: tool_name, tool_input, cwd
2. If <cwd>/.no-vibe/active does NOT exist → exit 0 (allow). Hook is inert outside no-vibe mode.
3. If tool_name not in {Edit, Write, NotebookEdit, MultiEdit} → exit 0 (allow).
4. Extract target path from tool_input (field varies by tool).
5. Resolve to absolute path.
6. If target is inside <cwd>/.no-vibe/ → exit 0 (allow — scratch escape hatch).
7. Otherwise → exit non-zero with deny message.
```

### Deny message

Returned via the hook's structured output, shown to both Claude and the user:

> no-vibe mode is active. You cannot write to `<path>` while learning. Show the code in chat instead, and let the user type it into their project themselves. If you need to save a lesson note or summary, write it under `.no-vibe/`.
>
> To exit no-vibe mode, the user can run `/no-vibe off`.

Claude will read this as a tool error and (per the skill's directive) immediately switch to showing the code in chat.

### What is NOT blocked

- `Read`, `Grep`, `Glob` — needed to study the project and references
- `Bash` — needed to run demos, clone refs, run user-authored code
- `WebFetch` — for pulling docs
- `Edit`/`Write`/`NotebookEdit` **inside `.no-vibe/`** — scratch escape hatch for `session.md` and `notes/`

### The Bash loophole

Technically AI could bypass the hook by using Bash to run `cat > src/foo.py <<EOF...EOF`. Two layers of defense:

1. **Skill-level rule:** SKILL.md explicitly says *"You must never use Bash to write to project files. The hook does not police Bash, but the rule still applies. Violating it defeats the entire plugin."* AI is cooperating with the user's stated goal (they installed this plugin specifically to enforce this), so it will respect the rule.
2. **Optional Bash guard (v2 / stretch):** The hook can additionally inspect Bash commands for `>`, `>>`, `tee`, `sed -i`, `cp` patterns targeting paths outside `.no-vibe/` and deny those too. Not required for v1.

**Why not block Bash entirely:** `bash -c "python user_script.py"` is how AI demonstrates output, and `git clone` is how refs are fetched. Blocking Bash would cripple the teaching cycle.

## 7. Lifecycle

### One-shot lesson

```
1. User: /no-vibe --ref pytorch build a linear layer like pytorch's
2. Command handler:
   a. mkdir -p .no-vibe/refs .no-vibe/notes
   b. git clone --depth 1 https://github.com/pytorch/pytorch .no-vibe/refs/pytorch (if missing)
   c. touch .no-vibe/active
   d. load skills/no-vibe/SKILL.md
3. Skill runs Phase 1a (context analysis + targeted clarification)
4. Skill runs Phase 1b (ref already provided, skip)
5. Skill runs Phase 1c (writes .no-vibe/session.md, presents curriculum)
6. User approves curriculum
7. Loop Phases 2–5 until curriculum complete:
   - Introduce → User writes → User runs → Review (Read file) → Check-in → Advance
   - Curriculum revised mid-flight if needed
8. Phase 6: synthesize → write .no-vibe/notes/2026-04-09-linear-layer.md
9. Command handler: rm .no-vibe/active
10. Normal Claude resumes
```

### Persistent mode

```
1. User: /no-vibe on
2. Command handler: touch .no-vibe/active, load skill
3. User: "build a linear layer like pytorch's"
4. Skill runs full cycle (steps 3–8 above), but leaves .no-vibe/active in place
5. User: "now teach me how autograd hooks into it"
6. Skill runs a new cycle — same session, same refs, new session.md
7. ... continues until ...
8. User: /no-vibe off
9. Command handler:
   - If a lesson is mid-flight, run Phase 6 synthesis to wrap it up
   - rm .no-vibe/active
10. Normal Claude resumes
```

### Resume after interruption

If the user closes Claude mid-lesson, `.no-vibe/active` and `.no-vibe/session.md` persist. On next invocation:

- If `/no-vibe on` mode → the skill detects the existing `session.md`, sees the curriculum checkboxes, and asks: *"Looks like we were mid-lesson on X at step 4. Resume, restart, or pick a new topic?"*
- If a one-shot was interrupted → command handler checks marker timestamp on startup and offers the same resume prompt.

## 8. Failure Modes

| Failure | Handling |
|---|---|
| `git clone` fails (no network, bad URL, rate limit) | Command reports error, asks user whether to proceed without the ref or abort. |
| `.no-vibe/` can't be created (permissions) | Command reports, exits cleanly, no partial state. |
| Hook not installed (plugin partially loaded) | Skill detects missing hook on startup and warns: *"Enforcement hook isn't active. I'll follow the no-code-in-files rule by instruction, but there's no hard block."* |
| User pastes a giant codebase into chat asking AI to "just summarize" | AI follows the skill's "no shortcuts" rule and walks through it via the cycle anyway. |
| User tries to invoke `/no-vibe` outside any project (no cwd writability) | Command exits with a message: "no-vibe needs a project directory to scratch into." |
| Reference project too large to clone shallowly | Command warns and asks for confirmation before cloning. |

## 9. Open Questions

None blocking. Two items deferred to a v2 plan:

1. **Bash write-guard** — should the hook inspect Bash commands for redirection patterns? Adds complexity; not strictly needed if the skill instruction is respected. Defer.
2. **Curriculum templates** — should `curriculum.md` ship with structured templates for common topics (ML layers, web frameworks, systems concepts), or stay as generic guidance? Defer until we see real usage patterns.

## 10. Implementation Notes for the Plan Phase

The current working directory `/home/rizki/Projects/instructure-mode/` already contains scaffolding under the name `instructure-mode`:

```
.claude-plugin/
├── plugin.json                  (name: "instructure-mode")
└── skills/instructure-mode/SKILL.md  (empty placeholder)
```

The implementation plan must begin with a full rename refactor:

- `plugin.json` → update `name`, `description`
- `.claude-plugin/skills/instructure-mode/` → rename to `.claude-plugin/skills/no-vibe/`
- (Optional, user's call) project directory `instructure-mode/` → rename to `no-vibe/`. This is risky to do mid-session and should be done by the user manually outside of Claude.

After the rename, implementation proceeds component by component: command file, skill file, curriculum file, hook script, plugin.json hook registration, end-to-end test of the cycle.
