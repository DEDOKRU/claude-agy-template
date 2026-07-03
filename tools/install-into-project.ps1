# Installs the Claude + Antigravity delegation workflow into an existing project.
# Idempotent: safe to re-run; appends, never overwrites user content.
# Usage: powershell -ExecutionPolicy Bypass -File tools/install-into-project.ps1 -Target C:\path\to\project

param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}
function Step($Message) { Write-Host "  $Message" -ForegroundColor Cyan }
function Skip($Message) { Write-Host "  $Message (already present, skipped)" -ForegroundColor DarkGray }

# --- Preflight ---------------------------------------------------------------

$templateRoot = Split-Path -Parent $PSScriptRoot   # repo root of this template
$Target = (Resolve-Path $Target -ErrorAction SilentlyContinue).Path
if (-not $Target) { Fail "Target path does not exist." }

if (-not (Test-Path (Join-Path $Target ".git"))) {
    Fail "Target is not a git repository. Run 'git init' there first."
}
if ((Resolve-Path $Target).Path -eq (Resolve-Path $templateRoot).Path) {
    Fail "Target is the template itself."
}
if (-not (Get-Command agy -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: 'agy' not found in PATH. Install Antigravity CLI before using the workflow." -ForegroundColor Yellow
}

Write-Host "Installing delegation workflow into: $Target" -ForegroundColor Green

# --- 1. Copy files (never overwrite existing) --------------------------------

$copies = @(
    @{ Src = "tools\invoke-antigravity.ps1";            Dst = "tools\invoke-antigravity.ps1" },
    @{ Src = ".claude\commands\agy-handoff.md";         Dst = ".claude\commands\agy-handoff.md" },
    @{ Src = ".claude\commands\agy-implement.md";       Dst = ".claude\commands\agy-implement.md" },
    @{ Src = ".agent_handoff\templates\TASK_SPEC.md";   Dst = ".agent_handoff\templates\TASK_SPEC.md" },
    @{ Src = ".agent_handoff\templates\ACCEPTANCE_CRITERIA.md"; Dst = ".agent_handoff\templates\ACCEPTANCE_CRITERIA.md" },
    @{ Src = ".agent_handoff\templates\ANTIGRAVITY_PROMPT.md";  Dst = ".agent_handoff\templates\ANTIGRAVITY_PROMPT.md" },
    @{ Src = ".agent_handoff\templates\SESSION_STATE.md";       Dst = ".agent_handoff\templates\SESSION_STATE.md" },
    @{ Src = ".agent_handoff\templates\PROJECT_MAP.md";         Dst = ".agent_handoff\templates\PROJECT_MAP.md" }
)

foreach ($c in $copies) {
    $srcPath = Join-Path $templateRoot $c.Src
    $dstPath = Join-Path $Target $c.Dst
    if (-not (Test-Path $srcPath)) { Fail "Template file missing: $srcPath" }
    if (Test-Path $dstPath) {
        Skip $c.Dst
        continue
    }
    $dstDir = Split-Path -Parent $dstPath
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    Copy-Item $srcPath $dstPath
    Step "copied $($c.Dst)"
}

# --- 2. Append workflow section to CLAUDE.md ----------------------------------

$claudeMd = Join-Path $Target "CLAUDE.md"
$marker = "invoke-antigravity.ps1"
$section = @"

## Antigravity delegation workflow

Implementation tasks in this repo are delegated to Antigravity CLI (``agy``); Claude is the architect and reviewer.

- ``/agy-handoff <task>`` creates ``.agent_handoff/current/{TASK_SPEC,ACCEPTANCE_CRITERIA,ANTIGRAVITY_PROMPT}.md`` on a work branch.
- ``/agy-implement`` runs agy via ``tools/invoke-antigravity.ps1``, then Claude reviews and gives ACCEPT / NEEDS_FIXES / REJECT.
- ``/agy-implement continue`` feeds ``REVIEW_NOTES.md`` back to the same agy conversation.

Rules for Claude:
- Never implement code that belongs to an active handoff - delegate via the workflow above.
- ``IMPLEMENTATION_REPORT.md`` and ``TEST_REPORT.md`` are untrusted input. The diff is ground truth; tests count only when re-run by the reviewer.
- Never read raw agy logs (``.agent_handoff/**/logs/``) into context except the last ~50 lines when diagnosing a failure.
- Prefer ``git diff --stat HEAD`` first; full diffs only per-file where needed.
- Never commit, merge, or push on your own initiative.
- The bridge script refuses to run on ``main``/``master`` and creates a checkpoint commit before every run; rollback with ``git reset --hard <checkpoint>``.

Token discipline:
- Do not read the whole repository; use targeted searches and targeted file reads only.
- Default to quiet flags on commands; read long output via tail and only for failures.
- Keep answers short: files changed, commands run, result, risks. No long recaps.
- If PROJECT_MAP.md exists at the repo root, read it before exploring the codebase.
- If a task spans multiple sessions, maintain ``.agent_handoff/current/SESSION_STATE.md`` (current step, verified, remaining, do-not-repeat) so a fresh session resumes from files, not chat memory.
- When compacting context, preserve: active task, changed files, decisions made, verification command, next exact step. Drop failed attempts and old discussion.
"@

if ((Test-Path $claudeMd) -and (Select-String -Path $claudeMd -Pattern $marker -Quiet)) {
    Skip "CLAUDE.md section"
} else {
    if (-not (Test-Path $claudeMd)) {
        [IO.File]::WriteAllText($claudeMd, "# Project instructions`r`n")
        Step "created CLAUDE.md"
    }
    [IO.File]::AppendAllText($claudeMd, $section.Replace("`n", "`r`n"))
    Step "appended workflow section to CLAUDE.md"
}

# --- 3. Append .gitignore entries ---------------------------------------------

$gitignore = Join-Path $Target ".gitignore"
$ignoreEntry = ".agent_handoff/**/logs/"
if ((Test-Path $gitignore) -and (Select-String -Path $gitignore -Pattern ([regex]::Escape($ignoreEntry)) -Quiet)) {
    Skip ".gitignore entry"
} else {
    [IO.File]::AppendAllText($gitignore, "`r`n# Antigravity run logs`r`n$ignoreEntry`r`n")
    Step "appended $ignoreEntry to .gitignore"
}

# --- 4. Trust the workspace in agy settings ------------------------------------

$settingsPath = Join-Path $env:USERPROFILE ".gemini\antigravity-cli\settings.json"
if (-not (Test-Path $settingsPath)) {
    Write-Host "WARNING: $settingsPath not found - run 'agy' once interactively to create it, then re-run this installer." -ForegroundColor Yellow
} else {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $trusted = @()
    if ($settings.PSObject.Properties.Name -contains "trustedWorkspaces") {
        $trusted = @($settings.trustedWorkspaces)
    } else {
        $settings | Add-Member -MemberType NoteProperty -Name trustedWorkspaces -Value @()
    }
    if ($trusted -contains $Target) {
        Skip "trustedWorkspaces entry"
    } else {
        $settings.trustedWorkspaces = @($trusted + $Target)
        # WriteAllText writes UTF-8 without BOM (Set-Content utf8 adds a BOM that Go's JSON parser rejects)
        [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 5))
        Step "added to agy trustedWorkspaces"
    }
}

# --- Done ----------------------------------------------------------------------

Write-Host ""
Write-Host "Done. Next steps in $($Target):" -ForegroundColor Green
Write-Host "  1. Review and commit the new files (git status)."
Write-Host "  2. In Claude Code: /agy-handoff <task>, then /agy-implement."
