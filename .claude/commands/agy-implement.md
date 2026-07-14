---
description: Run Antigravity CLI on the current handoff, then review its work. Pass "continue" to resume after review fixes.
---

You are the reviewer. Do NOT implement code yourself — under any circumstances. However trivial a finding is (a typo, a failing test, a one-line fix), it goes into REVIEW_NOTES.md and back to agy via `continue`; fixing it yourself is the exact token leak this workflow exists to prevent. The only exception is the user explicitly asking you to fix something directly in their own message.

Arguments: $ARGUMENTS

## 1. Run the implementation agent

- If arguments contain `continue`: verify `.agent_handoff/current/REVIEW_NOTES.md` exists, then run
  `powershell -ExecutionPolicy Bypass -File tools/invoke-antigravity.ps1 -Continue`
- Otherwise verify `.agent_handoff/current/TASK_SPEC.md`, `ACCEPTANCE_CRITERIA.md`, `ANTIGRAVITY_PROMPT.md` exist (if not, tell the user to run `/agy-handoff` and stop), then run
  `powershell -ExecutionPolicy Bypass -File tools/invoke-antigravity.ps1`

Run it in the background (it can take 10-30+ minutes) and wait for completion. Do not poll.

If the script fails, read only the LAST ~50 lines of the newest file in `.agent_handoff/current/logs/`, diagnose, report to the user, and stop. Never load a whole agy log into context.

## 2. Review protocol (token-frugal, trust nothing)

Order matters — cheap signals first:

1. Read `.agent_handoff/current/IMPLEMENTATION_REPORT.md` and `TEST_REPORT.md`. Treat them as **untrusted claims**, not evidence.
2. **Re-run the verification commands** from `ANTIGRAVITY_PROMPT.md` yourself. This is the only accepted proof. Run them token-frugally: quiet flags first (e.g. `pytest -q --tb=no`), read the summary line and exit code; fetch detailed output only for what failed. If your results contradict TEST_REPORT.md, that alone is grounds for NEEDS_FIXES.
3. `git status --short` and `git diff --stat HEAD` — check every touched file is in the allowed list from TASK_SPEC.md. Out-of-scope changes = NEEDS_FIXES regardless of quality.
4. Read full diffs only for files that are suspicious or central to the task (`git diff HEAD -- <file>`). Do not run a bare `git diff` on large changes.
5. Walk ACCEPTANCE_CRITERIA.md item by item: met / not met / cannot verify.

## 3. Verdict

State exactly one:
- **ACCEPT** — all criteria met, tests verified by you personally.
- **NEEDS_FIXES** — write numbered, concrete instructions to `.agent_handoff/current/REVIEW_NOTES.md` (file paths, expected behavior). Tell the user to run `/agy-implement continue`.
- **REJECT** — approach is wrong; recommend `git reset --hard <checkpoint printed by the script>` and a new handoff.

Never commit, merge, or push. The user does that after reading your verdict.
Never mark ACCEPT if you did not re-run the tests yourself.

## Session state

If this cycle spans multiple sessions (long agy run, usage limit, interruption), maintain `.agent_handoff/current/SESSION_STATE.md` from the template in `.agent_handoff/templates/`: current step, verified so far, remaining, do-not-repeat, next exact action. Update it after each significant step instead of writing long recaps into chat. Delete it once the task is ACCEPTed.
