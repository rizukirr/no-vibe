# no-vibe — Reference Grounding

Load this when `--ref` is attached to the session or user cites a reference project.

## The rule

When a reference project is attached, you MUST ground every **conceptual** code example in the reference's actual source. Trivial / mechanical layers (prints, renames, formatting) are exempt. Before each conceptual step, Grep the reference to find the real implementation. Quote with `file:line` citations.

If your mental model disagrees with the reference, trust the reference. **Never invent APIs or behaviors that aren't in the referenced code** — this applies universally, even to trivial layers where citation is skipped.

## Maturity mapping

User's code grows layer by layer; reference is usually a finished product. To cite "the same conceptual level":

1. Identify the **single responsibility** of the user's current layer (e.g. "compute a dot product", "store weights", "expose a callable").
2. In the reference, find the **smallest self-contained piece** that owns the same responsibility — usually a function, method, or init block, not the whole class.
3. Cite that piece. If the reference bundles your layer's concern with 2+ others (common in production code), quote only the relevant lines and name what you're deliberately *not* showing yet ("ignore the `__repr__` and `reset_parameters` — we'll get there").
4. If the reference's git history has a minimal early version of the same code (first-commit implementations are gold), prefer that over the current production form.

## Mismatches

- **No direct equivalent** → say so explicitly: *"no direct equivalent in `<ref>`; closest is `<file:line>` which does X instead because Y"*. Do not fabricate a citation.
- **Ref is more mature than this layer** → cite the ref but name what it does *beyond* the user's layer (e.g. *"pytorch's `Linear.__init__` also wraps the weight in `nn.Parameter` for autograd — we'll add that in layer N"*). Anchors the comparison without demanding user copy production complexity.
- **Trivially pedagogical layer** (e.g. *"add a `print`"*, *"rename a variable"*) → skip the citation. Reference grounding is for conceptual layers, not mechanical ones.

## No-ref case

If user did NOT pass `--ref`, Phase 1b proposes 2–3 candidates with distinct pedagogical angles (production-polished, minimal-real, pure-pedagogical). User picks; clone via Bash:

```bash
git clone --depth 1 <url> .no-vibe/refs/<name>/
```

Without a ref, conceptual explanations are still grounded — you just can't quote `file:line`. Default to well-known idiomatic patterns and flag uncertainty explicitly (*"standard pattern is X, but we don't have a ref pinned — if you want to verify, grab one"*) rather than speaking with false authority.
