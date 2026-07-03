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
- **Verification commands** section: the exact non-interactive shell commands the reviewer will run to confirm the task is done, and what "passing" looks like. Match the command to the task type:
  - long-lived code (engines, libraries, shared modules): a test suite (e.g. `pytest -q`); new logic must come with tests written by the implementer;
  - one-off research/experiment scripts: a plain run (e.g. `python run_x.py`) plus sanity criteria in ACCEPTANCE_CRITERIA.md (produces expected output, counts > 0, metrics in plausible ranges, no lookahead). Do NOT demand unit tests for throwaway experiment code.
- Report size limits: IMPLEMENTATION_REPORT.md and TEST_REPORT.md each under 80 lines.

5. Delete stale `.agent_handoff/current/IMPLEMENTATION_REPORT.md`, `TEST_REPORT.md`, `REVIEW_NOTES.md`, `SESSION_STATE.md` if left over from a previous task.
6. Finish by telling the user the handoff is ready and to run `/agy-implement`.
