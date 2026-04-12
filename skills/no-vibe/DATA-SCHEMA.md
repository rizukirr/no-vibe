---
name: no-vibe-data-schema
description: JSON contracts for learner tracking data files in .no-vibe/data/
---

# no-vibe — Data Schema

Reference for all JSON files in `.no-vibe/data/`. Read this before writing any data file.

## Directory Structure

```
.no-vibe/data/
├── profile.json
├── mistakes.json
└── sessions/
    └── <topic-slug>.json
```

## profile.json — Learner State

Tracks skill levels and patterns across all sessions. Created on first session if missing. Updated at end of each session (Phase 6).

```json
{
  "skill_levels": {},
  "total_sessions": 0,
  "total_layers_completed": 0,
  "common_strengths": [],
  "common_weaknesses": []
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `skill_levels` | `Record<string, Level>` | Topic area → skill level. Key is kebab-case (e.g. `python-numpy`, `rust-ownership`) |
| `total_sessions` | `number` | Count of completed sessions |
| `total_layers_completed` | `number` | Sum of layers completed across all sessions |
| `common_strengths` | `string[]` | Mistake categories the user rarely hits |
| `common_weaknesses` | `string[]` | Mistake categories with 3+ entries in mistakes.json |

### Skill Levels

Progression: `new` → `struggling` → `developing` → `comfortable` → `strong`

Update logic (Phase 6):
- mistakes_this_session == 0 → move up one level
- mistakes_this_session <= 1 and layers_completed >= 5 → move up one level
- mistakes_this_session >= 3 → move down one level
- Otherwise → stay

## mistakes.json — Mistake Log

Append-only array. Created on first mistake if missing. Appended during Phase 4 (review) when an issue is found.

```json
[
  {"category": "off-by-one", "topic": "linear layer", "layer": 3}
]
```

### Fields

| Field | Type | Description |
|---|---|---|
| `category` | `string` | Freeform kebab-case. Reuse existing categories when a match exists. Examples: `off-by-one`, `missing-import`, `type-mismatch`, `wrong-operator`, `scope-error`, `syntax-error` |
| `topic` | `string` | Session topic (human-readable, matches session's `topic` field) |
| `layer` | `number` | Which curriculum layer the mistake occurred at |

## sessions/\<topic-slug\>.json — Session Snapshot

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

### Fields

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
| `mistakes_this_session` | `number` | Count of issues found in Phase 4 this session |
| `refs` | `string[]` | Reference project names used |

### Status Transitions

- `in_progress` → `completed` (Phase 6 reached)
- `in_progress` → `abandoned` (user starts fresh session over this one)

## Initializing Data Files

When a data file is missing, create it with defaults:
- `profile.json` → `{"skill_levels":{},"total_sessions":0,"total_layers_completed":0,"common_strengths":[],"common_weaknesses":[]}`
- `mistakes.json` → `[]`
- Session files → created fresh per session

Never fail on missing data files. Always initialize with defaults.
