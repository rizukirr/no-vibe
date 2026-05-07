# no-vibe — Curriculum Reference

This file is a pedagogical reference the SKILL can pull in for structured topics. It is **not** required reading on every invocation — only consult it when a topic matches one of the patterns below.

## When to use these patterns

These are starting templates, not rigid scripts. The Phase 1c curriculum draft can adapt one of these to the user's specific request, then revise on the fly during the cycle.

## Pattern 1: Building a primitive from scratch (e.g., a layer, a parser, a queue)

Top-down descent template:

1. Empty function/class skeleton with a print — runnable, proves the call works
2. Add the data the primitive holds (parameters, state) as plain Python types
3. The simplest possible operation, hard-coded to one shape, no abstraction
4. Generalize to handle the obvious next case (variable input shape, multiple items)
5. Replace the manual approach with a library/idiomatic version
6. Compare against the canonical reference implementation
7. Synthesize + advanced pointers

## Pattern 2: Understanding an existing API (e.g., "how does Promise work")

Top-down descent template:

1. Use the API at its highest level (one call, one observable output)
2. Trace what it returns / what state it produces
3. Build a stripped-down version that replicates the surface API on a toy case
4. Add the next layer of complexity (error handling, chaining, etc.)
5. Compare your stripped version to the real source — identify what you simplified away
6. Synthesize + advanced pointers

## Pattern 3: Debug mode — starting from a symptom

Inverted template (root-cause descent):

1. Reproduce the symptom in isolation — runnable, fails the same way
2. Form 2–3 hypotheses about the cause; rank by likelihood
3. Cheapest test to discriminate between hypotheses; user runs it
4. Narrow based on the result; new hypothesis if needed
5. Identify root cause; user implements the fix themselves
6. Verify symptom is gone; verify nothing else broke
7. Synthesize: what was the gap in mental model that allowed the bug?

## Coaching framings — short maxims to surface when the moment fires

These are one-liners the AI can deploy *to the user* during teaching when a specific behavior shows up. They are pedagogy, not plugin behavior — the AI does not enforce them on the user, just names the principle so the user can decide. Use sparingly: one framing per teaching turn at most, and only when the trigger fires plainly. Adapted from Karpathy's coding-with-LLMs guidelines (`external/andrej-karpathy-skills/`).

- **Simplicity First.** *Trigger:* user added a class hierarchy, config flag, or abstraction layer the layer's stated goal didn't require. *Framing:* "Only build what this layer needs to satisfy its run command. The next layer can earn the abstraction if it actually shows up — most don't."
- **Surgical Changes.** *Trigger:* user did a drive-by rename, reformat, or refactor in a file they were touching for an unrelated reason. *Framing:* "Every changed line should trace back to the layer's stated goal. Cleanup is a separate layer with its own goal — make it visible, don't bundle it."
- **Goal-Driven Execution.** *Trigger:* user starts coding before they can say what success looks like, or asks "is this right?" without a runnable check. *Framing:* "State the verifiable signature before writing the function — what command will you run, what will it print, how will you know it passed? Code before that question is answered is exploration, not progress."
- **Think Before Coding.** *Trigger:* Phase 4 Block verdict reveals the user assumed an API behavior or type shape that turned out wrong. *Framing:* "Before the next attempt, list the 2–3 assumptions you're making about scope, input shape, and external API behavior. Verify or falsify each one before you type."

These are coaching prompts, not contract rules. If the user pushes back ("I want the abstraction now"), respect that — the framings exist to surface the question, not to win it.

## Anti-patterns to avoid

- **Lecturing without running.** Every layer must produce something the user can run and see.
- **More than one new concept per layer.** If you find yourself explaining two things, split the layer.
- **Blowing the explanation budget.** 1–4 sentences per layer (up to 6 in concept mode for mental-model territory). Past that, split the layer instead of writing more prose.
- **Preamble, recap, preview, cheerleading.** "Great! Now let's…" / "In the last step we…" / "Coming up next…" / "Awesome work!" — all noise. Show the layer, explain it, give the run command, stop.
- **Inventing API surface that isn't in the reference.** When a ref is attached, grep first.
- **Skipping Phase 1a context analysis.** A curriculum without intake is a guess.
- **Silent curriculum revisions.** Always announce changes with *why*.
