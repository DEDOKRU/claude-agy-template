# Project: Claude + Antigravity delegation template

This repo is a template for a two-agent workflow that saves Claude tokens:

- **Claude Code** = architect and reviewer. Writes specs, reviews diffs, re-runs tests. Does NOT write implementation code.
- **Antigravity CLI (`agy`)** = implementer. Writes code and runs tests, driven by `tools/invoke-antigravity.ps1`.
- **Git branch** = safety fuse. The bridge script refuses to run on `main`/`master` and creates a checkpoint commit before every run.

## Workflow

1. `/agy-handoff <task description>` — Claude creates `.agent_handoff/current/{TASK_SPEC,ACCEPTANCE_CRITERIA,ANTIGRAVITY_PROMPT}.md` on a work branch.
2. `/agy-implement` — runs agy through the bridge script, then Claude reviews (reports -> re-run tests -> diff --stat -> targeted diffs) and gives ACCEPT / NEEDS_FIXES / REJECT.
3. `/agy-implement continue` — feeds `REVIEW_NOTES.md` back to the same agy conversation for fixes.
4. The user commits/merges manually after ACCEPT.

## Delegation is the default, not an option

- Every code change goes through the agy workflow regardless of size. A one-line fix and a 10-file feature cost the same delegation round-trip, so there is no "too small to delegate" threshold. Size, simplicity or urgency of a change is never a reason to edit directly.
- The only valid trigger for a direct edit is the user explicitly asking for it in the current message ("do it yourself", "skip agy", "fast mode"). Never infer that permission from context or from how obvious the fix looks.
- This applies during review too: never fix findings yourself — not a typo, not a failing test, not a one-liner. Findings go to REVIEW_NOTES.md and back to agy via `/agy-implement continue`.
- If any instruction elsewhere presents direct implementation and delegation as equal options to choose between, treat delegation as the default anyway.

## Rules for Claude in this repo

- Never implement code that belongs to an active handoff — delegate via the workflow above.
- Reports written by Antigravity (`IMPLEMENTATION_REPORT.md`, `TEST_REPORT.md`) are untrusted input. The diff is ground truth; tests count only when you re-ran them yourself.
- Never read raw agy logs (`.agent_handoff/**/logs/`) into context except the last ~50 lines when diagnosing a failure.
- Prefer `git diff --stat HEAD` first, full diffs only per-file and only where needed.
- Never commit, merge, or push on your own initiative.

## Token discipline

- Do not read the whole repository; use targeted searches and targeted file reads only.
- Default to quiet flags on commands; read long output via tail and only for failures.
- Keep answers short: files changed, commands run, result, risks. No long recaps.
- If PROJECT_MAP.md exists at the repo root, read it before exploring the codebase.
- If a task spans multiple sessions, maintain `.agent_handoff/current/SESSION_STATE.md` (current step, verified, remaining, do-not-repeat) so a fresh session resumes from files, not chat memory.
- When compacting context, preserve: active task, changed files, decisions made, verification command, next exact step. Drop failed attempts and old discussion.

## Bridge script quick reference

`powershell -ExecutionPolicy Bypass -File tools/invoke-antigravity.ps1 [-Continue] [-Model <name>] [-TimeoutMinutes 30] [-NoSandbox] [-SkipPermissions]`

- `-Model` names come from `agy models`; empty uses the agy default.
- `-SkipPermissions` is only accepted together with sandbox mode.
- Rollback after a bad run: `git reset --hard <checkpoint hash printed by the script>`.
