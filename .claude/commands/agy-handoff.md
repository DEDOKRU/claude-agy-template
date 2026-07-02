---
description: Create a handoff package (spec + acceptance criteria + prompt) for Antigravity CLI. Claude plans, does not implement.
---

You are the architect. Prepare a handoff for the Antigravity implementation agent based on this task:

$ARGUMENTS

Rules:
1. Do NOT write implementation code yourself. Your output is the contract, not the code.
2. If the current branch is `main` or `master`, create and switch to a work branch first: `git checkout -b agy/<short-task-slug>`.
3. Explore the codebase only as much as needed to write a precise spec (prefer Glob/Grep over reading whole files).
4. Create these files (overwrite if they exist):

`.agent_handoff/current/TASK_SPEC.md`
- Goal (1-3 sentences), context the agent needs, exact scope.
- **Allowed files** list (files/globs the agent may create or modify). Everything else is off-limits.
- Explicit non-goals ("do not refactor X", "do not touch config Y").

`.agent_handoff/current/ACCEPTANCE_CRITERIA.md`
- Numbered, individually checkable criteria. Each one must be verifiable from the diff or by running a command.

`.agent_handoff/current/ANTIGRAVITY_PROMPT.md`
- Task-specific guidance: relevant file paths, conventions to follow, gotchas.
- **Test commands** section: the exact shell commands to run tests, and what "passing" looks like. These same commands will be re-run by the reviewer, so they must work non-interactively.
- Report size limits: IMPLEMENTATION_REPORT.md and TEST_REPORT.md each under 80 lines.

5. Delete stale `.agent_handoff/current/IMPLEMENTATION_REPORT.md`, `TEST_REPORT.md`, `REVIEW_NOTES.md` if left over from a previous task.
6. Finish by telling the user the handoff is ready and to run `/agy-implement`.
