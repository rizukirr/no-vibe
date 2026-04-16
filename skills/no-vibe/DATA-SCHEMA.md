---
name: no-vibe-data-schema
description: JSON contracts for learner tracking data files at project and global levels
---

# no-vibe — Data Schema

Data lives at two levels. Read this before writing any data file.

## Two-Tier Architecture

**Global (`~/.no-vibe/`)** — synthesized learner identity, follows across all projects:
```
~/.no-vibe/
├── profile.json          # Skill levels, stats, strengths/weaknesses
├── profile.md            # AI's free-form understanding of learner
└── mistakes.json         # All mistakes ever, tagged with project + date
```

**Project (`.no-vibe/data/`)** — raw session data, specific to this codebase:
```
.no-vibe/data/
├── mistakes.json         # Raw mistakes from this project only
└── sessions/
    └── <topic-slug>.json # Per-session snapshots
```

**Read order:** global first (big picture), then project (specific context).
**Write order:** project first (raw data), then global (synthesis).

---

## Global Level (`~/.no-vibe/`)

### profile.json — Learner State (Global)

Synthesized cross-project profile. Initialized by command wrapper on activation. Updated at end of each session (Phase 6) or when session is closed early (`/no-vibe off`). Must always reflect AI's observations, even from incomplete sessions.

```json
{
  "skill_levels": {
    "c-arrays": "developing",
    "python-numpy": "comfortable"
  },
  "total_sessions": 12,
  "total_layers_completed": 87,
  "common_strengths": ["list-comprehension", "function-composition"],
  "common_weaknesses": ["off-by-one-fencepost", "type-confusion-list-vs-scalar"],
  "projects": {
    "numc": { "sessions": 4, "last_session": "2026-04-14" },
    "ccompose": { "sessions": 3, "last_session": "2026-04-15" }
  }
}
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `skill_levels` | `Record<string, Level>` | Topic area → skill level. Key is kebab-case (e.g. `python-numpy`, `rust-ownership`) |
| `total_sessions` | `number` | Count of sessions across all projects |
| `total_layers_completed` | `number` | Sum of layers completed across all projects |
| `common_strengths` | `string[]` | Mistake categories the user rarely hits |
| `common_weaknesses` | `string[]` | Mistake categories with 3+ entries in global mistakes.json |
| `projects` | `Record<string, ProjectEntry>` | Per-project session counts and last activity |

#### ProjectEntry

| Field | Type | Description |
|---|---|---|
| `sessions` | `number` | Session count in this project |
| `last_session` | `string` | ISO date of last session in this project |

#### Skill Levels

Progression: `new` → `struggling` → `developing` → `comfortable` → `strong`

Update logic (Phase 6 or early close):
- mistakes_this_session == 0 → move up one level
- mistakes_this_session <= 1 and layers_completed >= 5 → move up one level
- mistakes_this_session >= 3 → move down one level
- Otherwise → stay

On early close (session incomplete), apply the same logic using partial data. Even one completed layer with zero mistakes is a signal worth recording.

### profile.md — Learner Understanding (Global)

Free-form Markdown written by AI. Captures observations that don't fit structured fields: learning patterns, cross-project insights, teaching approach preferences.

AI rewrites this at every session end. Not append-only — AI synthesizes a fresh understanding each time, informed by all available data.

Example:
```markdown
## Learning Patterns
Learns best with concrete examples before theory. Prefers building from scratch over modifying existing code.

## Cross-Project Observations
Consistently struggles with array bounds in C (numc, muslimtify) but handles Python indexing well — likely a pointer vs index mental model gap.

## Teaching Notes
Responds well to "deliberately absent" explanations. Gets frustrated with too many scaffolding layers — prefers jumping in and fixing mistakes.
```

### mistakes.json — Mistake Log (Global)

Append-only array. Enriched copy of project-level mistakes with project name and date.

```json
[
  {"category": "off-by-one-fencepost", "topic": "tensor indexing", "layer": 3, "project": "numc", "date": "2026-04-10"},
  {"category": "type-confusion-list-vs-scalar", "topic": "compose draw API", "layer": 4, "project": "ccompose", "date": "2026-04-15"}
]
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `category` | `string` | Freeform kebab-case. Reuse existing categories when a match exists |
| `topic` | `string` | Session topic (human-readable) |
| `layer` | `number` | Which curriculum layer the mistake occurred at |
| `project` | `string` | Project directory name where mistake occurred |
| `date` | `string` | ISO date (YYYY-MM-DD) when mistake was observed |

---

## Project Level (`.no-vibe/data/`)

### mistakes.json — Mistake Log (Project)

Append-only array. Raw mistakes from this project only. No `project` or `date` fields.

```json
[
  {"category": "off-by-one-fencepost", "topic": "tensor indexing", "layer": 3}
]
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `category` | `string` | Freeform kebab-case. Reuse existing categories when a match exists |
| `topic` | `string` | Session topic (human-readable) |
| `layer` | `number` | Which curriculum layer the mistake occurred at |

### sessions/\<topic-slug\>.json — Session Snapshot

One file per session. Created at Phase 1c. Updated at every phase transition. Topic slug: lowercase topic, spaces to hyphens, strip non-alphanumeric except hyphens, max 50 chars.

"Build a Linear Layer" → `build-a-linear-layer.json`

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
  "mistakes_this_session": 0,
  "refs": ["pytorch"]
}
```

#### Fields

| Field | Type | Description |
|---|---|---|
| `topic` | `string` | Human-readable session topic |
| `mode` | `string` | `concept`, `skill`, or `debug` |
| `status` | `string` | `in_progress` → `completed` or `abandoned` |
| `started` | `string` | ISO date (YYYY-MM-DD) |
| `layers_total` | `number` | Total curriculum layers planned |
| `layers_completed` | `number` | Layers user has finished |
| `current_phase` | `string` | `phase1a`..`phase6` |
| `current_layer` | `number` | Current layer index (1-based, 0 = not started) |
| `mistakes_this_session` | `number` | Count of issues found this session |
| `refs` | `string[]` | Reference project names used |

#### Status Transitions

- `in_progress` → `completed` (Phase 6 reached)
- `in_progress` → `abandoned` (user starts fresh session over this one)

---

## Initializing Data Files

The command wrapper initializes data files at both levels on activation:

**Global (`~/.no-vibe/`):**
- `profile.json` → `{"skill_levels":{},"total_sessions":0,"total_layers_completed":0,"common_strengths":[],"common_weaknesses":[],"projects":{}}`
- `profile.md` → empty file
- `mistakes.json` → `[]`

**Project (`.no-vibe/data/`):**
- `mistakes.json` → `[]`
- Session files → created fresh per session at Phase 1c

If a data file is missing despite eager init, create it with the defaults above before writing.
