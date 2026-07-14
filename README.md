# claude-agy-template

**English** | [Deutsch](README.de.md) | [Русский](README.ru.md)

A project template that pairs **Claude Code** (architect & reviewer) with **Antigravity CLI** (`agy`, implementer) to save Claude tokens: Claude writes the contract and reviews the result; agy writes the code and runs the tests; a PowerShell bridge connects them; a git branch acts as the safety fuse.

```text
Claude Code  -> /agy-handoff   -> contract (spec + acceptance criteria + prompt)
Claude Code  -> /agy-implement -> tools/invoke-antigravity.ps1 -> agy implements & tests
Claude Code  -> re-runs verification itself + reads the diff -> ACCEPT / NEEDS_FIXES / REJECT
you          -> commit / merge manually
```

Why it saves tokens: Claude never writes boilerplate, never babysits test runs, never re-reads the whole project. The expensive work (implementation, red-test debugging, reruns) happens on the Gemini side via Antigravity.

## Requirements

- Windows with PowerShell 5.1+ (the bridge and installer are PowerShell scripts)
- [Claude Code](https://code.claude.com) CLI
- [Antigravity CLI](https://antigravity.google) — `agy` in PATH, logged in once interactively
- git

## Install — the same block for new and existing projects

Open PowerShell **in your project folder** and paste this block as-is:

```powershell
$t = "$env:TEMP\agy-tpl"
if (Test-Path $t) { Remove-Item -Recurse -Force $t }
git clone --depth 1 https://github.com/DEDOKRU/claude-agy-template.git $t
powershell -ExecutionPolicy Bypass -File $t\tools\install-into-project.ps1 -Target .
Remove-Item -Recurse -Force $t
```

The installer is idempotent (safe to re-run) and never overwrites your content:

- copies the bridge script, the `/agy-handoff` + `/agy-implement` commands and the handoff templates;
- **appends** a rules section to your existing `CLAUDE.md` (or creates one);
- **appends** `.agent_handoff/**/logs/` to `.gitignore`;
- registers the project path in agy's `trustedWorkspaces` (headless agy runs hang without it).

### Scenario 1: brand-new project

1. **Use this template** button on GitHub → create your repository.
2. `git clone` it locally.
3. Run the install block inside the folder — files are skipped (already there), but the workspace gets registered with agy.

### Scenario 2: existing project

1. Make sure it is a git repository with at least one commit (`git init` + initial commit if not — the checkpoint/rollback/diff mechanics need a baseline).
2. Run the install block, review `git status`, commit.
3. Restart Claude Code in the project so the new commands load.

### Scenario 3: updating an already-connected project

The installer deliberately never overwrites existing files, so updating goes through deletion:

```powershell
Remove-Item tools\invoke-antigravity.ps1, .claude\commands\agy-handoff.md, .claude\commands\agy-implement.md
```

Then run the install block again — it fetches fresh copies.

## The working cycle

1. `/agy-handoff <task description>` — Claude creates a work branch `agy/<name>` and the contract: what to do, which files may be touched, how to verify, acceptance criteria.
2. `/agy-implement` — the bridge makes a checkpoint commit, agy implements and verifies (typically 5–30 min), then Claude reviews: re-runs the verification commands itself, checks the diff against the allowed-files list, walks the acceptance criteria.
3. Verdict:
   - **ACCEPT** — you merge (or open a PR).
   - **NEEDS_FIXES** — feedback is already in `REVIEW_NOTES.md`; run `/agy-implement continue`, agy fixes within the same conversation, Claude re-reviews.
   - **REJECT** — roll back with `git reset --hard <checkpoint>` (hash printed by the script) and write a new handoff.

The only manual actions in the whole cycle are the two commands above and the final merge: Claude never commits, merges or pushes — that is a safety fuse.

## Delegation is the default — no size threshold

The single biggest leak in any token-saving setup is the agent deciding "this change is too small to bother delegating." The rules installed into `CLAUDE.md` therefore remove that judgment entirely:

- **Every** code change goes through the agy cycle — a one-line fix and a 10-file feature cost the same delegation round-trip, so no "too small" threshold exists.
- The only trigger for a direct edit by Claude is you explicitly asking for it in the current message ("do it yourself", "skip agy", "fast mode"). Permission is never inferred from context, urgency, or how obvious the fix looks.
- This holds during review too: a trivial finding (typo, failing test, one-liner) goes to `REVIEW_NOTES.md` and back to agy — the reviewer never "quickly fixes" it in place.

The general pattern: any instruction that lets an agent choose between "cheap via delegation" and "expensive but immediate" based on its own judgment of the task will eventually pick the expensive path exactly where savings mattered most — on the stream of frequent small edits. The rule must remove the judgment, not guide it.

## Safety fuses

- The bridge refuses to run on `main`/`master` and without handoff files.
- A checkpoint commit before every agy run: `git diff HEAD` shows exactly the agent's changes; rollback is one command.
- agy runs with `--sandbox`; `--dangerously-skip-permissions` is only accepted together with sandbox mode.
- `--print-timeout 30m` (agy's 5-minute default would cut off real tasks).
- agy's reports are treated as untrusted input: Claude must re-run the verification commands itself before an ACCEPT.
- Verification commands match the task type: a test suite for long-lived code, a plain run + sanity criteria for one-off research scripts.

## Token hygiene (your habits — the template cannot automate these)

- **`/clear` after every completed task.** One endless session across 20 tasks is the biggest limit-killer: stale context is billed on every message. `/rename <name>` first if you may need to come back.
- **Corrected Claude twice? Don't correct a third time.** The context is polluted; `/clear` plus a sharper prompt is cheaper and works better.
- **Check `/context` and `/mcp` periodically.** Unused MCP servers cost context on every message — disable what the current work doesn't need.
- **`/compact` with instructions, not bare**: `/compact keep only the active task, changed files, decisions, verification command and next step` (the same rule is baked into the project `CLAUDE.md`, so auto-compaction honors it too).
- **Add a `PROJECT_MAP.md`** at the repo root for bigger projects (template in `.agent_handoff/templates/`) — Claude reads the map instead of walking the tree.
- **Interrupted work resumes from a file, not from chat memory**: project rules require maintaining `.agent_handoff/current/SESSION_STATE.md` for multi-session tasks — a fresh session starts from it instead of re-deriving context.

## Pitfalls discovered on live runs (already handled by the scripts)

- agy in `-p` print mode waits for stdin EOF and hangs forever on an open pipe — the bridge closes stdin via a `$null |` pipe.
- A workspace missing from `trustedWorkspaces` (`~/.gemini/antigravity-cli/settings.json`) makes headless runs hang — the installer registers it.
- agy silently self-updates on launch (a download that can look like a hang — it is a one-off pause).
- agy's default print timeout is only 5 minutes — the bridge sets 30.
- `agy models` only prints its list in a real interactive terminal.
- PowerShell 5.1 reads BOM-less scripts in the ANSI codepage: a UTF-8 em dash becomes a smart quote that breaks string parsing — both scripts are pure ASCII for that reason.

## Repository layout

```text
.claude/commands/agy-handoff.md    # Claude: create the contract for agy
.claude/commands/agy-implement.md  # Claude: run agy and review
tools/invoke-antigravity.ps1       # bridge: checks, checkpoint, agy run, summary
tools/install-into-project.ps1     # installer for new/existing projects
.agent_handoff/templates/          # contract, session-state and project-map templates
CLAUDE.md                          # rules for Claude in this repo
```

## License

[MIT](LICENSE)
