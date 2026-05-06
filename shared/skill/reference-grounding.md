# Reference Grounding

Load when `--ref` is attached or user cites a reference project.

## Rule

When a reference is attached, ground every **conceptual** code example in real source. Trivial / mechanical layers (prints, renames, formatting) exempt. Before each conceptual step, Grep the reference to find the real implementation. Quote with `file:line`.

If your mental model disagrees with the reference, trust the reference. Never invent APIs or behaviors not in the referenced code — applies even to trivial layers where citation is skipped.

## Maturity mapping

User's code grows layer by layer; reference is finished. To cite the same conceptual level:

1. Identify the user's current layer's **single responsibility** (compute a dot product, store weights, expose a callable).
2. Find the smallest self-contained piece in the reference owning that responsibility — usually a function or init block, not the whole class.
3. Cite that piece. If it bundles 2+ concerns, quote only the relevant lines and name what you're deliberately not showing yet.
4. If the reference's git history has a minimal early version of the same code, prefer that over the current production form.

## Mismatches

- **No equivalent** → say so: *"no direct equivalent in `<ref>`; closest is `<file:line>` which does X instead because Y"*. No fabricated citation.
- **Ref more mature** → cite + name what it does *beyond* this layer (*"pytorch's `Linear.__init__` also wraps weight in `nn.Parameter` for autograd — we'll add that in layer N"*).
- **Trivially pedagogical layer** → skip citation.

## No-ref case

Phase 1b proposes 2–3 candidates with distinct angles. User picks; clone via Bash. Without a ref, conceptual explanations are still grounded — flag uncertainty explicitly (*"standard pattern is X, but no ref pinned — if you want to verify, grab one"*) rather than speaking with false authority.
