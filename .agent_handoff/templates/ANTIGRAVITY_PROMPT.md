# Implementation guidance

## Relevant code
<paths + one-line descriptions of files the agent should read first>

## Conventions
<naming, error handling, style specifics of this repo>

## Gotchas
<known traps: platform issues, flaky areas, ordering requirements>

## Verification commands
Run these exactly; they must work non-interactively (the reviewer re-runs the same commands to accept the work). For long-lived code this is a test suite; for one-off research scripts a plain run + sanity criteria is enough:

```powershell
<e.g. npm test / pytest -q / dotnet test>
```

Passing looks like: <what output counts as green>

## Reports
- Write `.agent_handoff/current/IMPLEMENTATION_REPORT.md` — what changed and why. Under 80 lines.
- Write `.agent_handoff/current/TEST_REPORT.md` — exact commands run + real results. Under 80 lines. Never fabricate results.
