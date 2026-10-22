---
name: no-vibe-challenge
description: "One coding challenge built from the current syllabus or the project. The user writes all the code. The agent gives the task, hints when asked, and reviews when asked."
argument-hint: "[focus]"
command: true
---

# no-vibe-challenge

Give the user one hands-on challenge. The user writes every line.

## 1. Turn on the guard

Remember whether `.no-vibe/active` exists, then run:

```bash
mkdir -p .no-vibe && touch .no-vibe/active
```

## 2. Pick the challenge

- If `.no-vibe/syllabus.md` exists, build the challenge from sections already ticked, at its `level`, explained in its `teaching` style.
- Otherwise look at the project to infer the stack and pick something relevant to it.
- If `.no-vibe/project.md` exists, use its stack and versions. The challenge stays a separate exercise outside the project.
- A focus argument narrows the topic.

## 3. Present it

> **Challenge: {title}**
>
> {1 to 3 sentences}
>
> **Done when:**
> - {observable criterion}
> - {observable criterion}
>
> **Run:** `{exact command}`
>
> Ask for a hint anytime, or say review when you are done.

- Show no solution code.
- Every criterion is something the user can run and observe.
- The scope fits 5 to 20 minutes.
- A hint narrows the problem without giving code.
- Review only when asked: read the user's code and give short feedback anchored to lines.

## 4. Finish

If `.no-vibe/active` did not exist before step 1, run `rm -f .no-vibe/active`.

## Hard rules

- Never write to project files. While active, `.no-vibe/**` is the only write-allowed area.
- Keep the scope to 5 to 20 minutes.
