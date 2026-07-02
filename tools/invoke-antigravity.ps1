# Bridge script: Claude Code (architect/reviewer) -> Antigravity CLI (implementer).
# Windows PowerShell 5.1 compatible. No stderr redirection on native calls
# (2>&1 + ErrorActionPreference=Stop kills the script on the first stderr line).

param(
    [string]$TaskDir = ".agent_handoff/current",
    [string]$Model = "",                  # empty = agy session default; check names with `agy models`
    [int]$TimeoutMinutes = 30,            # agy --print-timeout; default 5m is too short for real tasks
    [switch]$Continue,                    # resume previous agy conversation to apply REVIEW_NOTES.md
    [switch]$NoSandbox,                   # disable agy --sandbox (use if sandbox is broken on this machine)
    [switch]$SkipPermissions              # agy --dangerously-skip-permissions; only makes sense with sandbox + work branch
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

# --- Preflight checks -------------------------------------------------------

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { Fail "Must be run inside a git repository." }
Set-Location $repoRoot

if (-not (Get-Command agy -ErrorAction SilentlyContinue)) {
    Fail "Antigravity CLI 'agy' not found in PATH. Install it and run 'agy' once interactively to log in."
}

$branch = git branch --show-current
if ($branch -in @("main", "master")) {
    Fail "Refusing to run on '$branch'. Create a work branch first: git checkout -b agy/<task-name>"
}

if ($SkipPermissions -and $NoSandbox) {
    Fail "-SkipPermissions without sandbox is not allowed. Drop one of the flags."
}

$taskSpec   = Join-Path $TaskDir "TASK_SPEC.md"
$acceptance = Join-Path $TaskDir "ACCEPTANCE_CRITERIA.md"
$agyPrompt  = Join-Path $TaskDir "ANTIGRAVITY_PROMPT.md"
$reviewNotes = Join-Path $TaskDir "REVIEW_NOTES.md"

foreach ($f in @($taskSpec, $acceptance, $agyPrompt)) {
    if (-not (Test-Path $f)) { Fail "Missing $f. Run /agy-handoff first." }
}
if ($Continue -and -not (Test-Path $reviewNotes)) {
    Fail "-Continue requires $reviewNotes with review feedback."
}

# --- Checkpoint commit ------------------------------------------------------
# Guarantees `git diff HEAD` afterwards shows exactly what the agent changed,
# and makes rollback a single `git reset --hard`.

$dirty = git status --porcelain
if ($dirty) {
    git add -A
    git commit -m "checkpoint: before agy run ($branch)" --quiet
    Write-Host "Checkpoint commit created (working tree was dirty)." -ForegroundColor Yellow
}
$checkpoint = git rev-parse HEAD
Write-Host "Checkpoint: $checkpoint" -ForegroundColor Cyan

# --- Build prompt -----------------------------------------------------------

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logsDir = Join-Path $TaskDir "logs"
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
$agyLog    = Join-Path $logsDir "agy-$timestamp.log"
$stdoutLog = Join-Path $logsDir "agy-$timestamp.stdout.txt"

if ($Continue) {
    $prompt = @"
Continue the previous task. The reviewer left feedback in $reviewNotes.

1. Read $reviewNotes and fix every listed issue. Do not expand scope beyond it.
2. Re-run the tests specified in $agyPrompt.
3. Update $TaskDir/IMPLEMENTATION_REPORT.md and $TaskDir/TEST_REPORT.md (keep each under 80 lines).
4. TEST_REPORT.md must contain the exact commands you ran and their real results. Do not fabricate results.
5. Stop after implementation and testing. Do not commit.
"@
} else {
    $prompt = @"
You are the implementation agent. Work only inside this git repository: $repoRoot

Read these files first:
- $taskSpec
- $acceptance
- $agyPrompt

Hard rules:
1. Follow TASK_SPEC.md exactly. Do not expand scope or redesign architecture.
2. Do not touch files outside the allowed list in TASK_SPEC.md.
3. Run the tests specified in ANTIGRAVITY_PROMPT.md. If they fail, fix the code and re-run.
4. Write $TaskDir/IMPLEMENTATION_REPORT.md (what changed and why, under 80 lines).
5. Write $TaskDir/TEST_REPORT.md with the exact commands run and their real output summary (under 80 lines). Do not fabricate results.
6. Do not commit. Stop after implementation and testing.

Return only a short final summary after writing the reports.
"@
}

# --- Run agy ----------------------------------------------------------------

$agyArgs = @("--print-timeout", "${TimeoutMinutes}m", "--log-file", $agyLog)
if ($Model)    { $agyArgs += @("--model", $Model) }
if ($Continue) { $agyArgs += "-c" }
if (-not $NoSandbox)  { $agyArgs += "--sandbox" }
if ($SkipPermissions) { $agyArgs += "--dangerously-skip-permissions" }
$agyArgs += @("-p", $prompt)

Write-Host "Running agy (timeout ${TimeoutMinutes}m, sandbox=$(-not $NoSandbox), continue=$([bool]$Continue))..." -ForegroundColor Cyan

& agy @agyArgs | Tee-Object -FilePath $stdoutLog
$exitCode = $LASTEXITCODE

# --- Result summary ---------------------------------------------------------

if ($exitCode -ne 0) {
    Write-Host "agy exited with code $exitCode. Logs: $agyLog / $stdoutLog" -ForegroundColor Red
    Write-Host "Rollback if needed: git reset --hard $checkpoint" -ForegroundColor Yellow
    exit $exitCode
}

Write-Host ""
Write-Host "=== agy finished. Changes vs checkpoint $checkpoint ===" -ForegroundColor Green
git status --short
git diff --stat HEAD
Write-Host ""
Write-Host "Reports: $TaskDir/IMPLEMENTATION_REPORT.md, $TaskDir/TEST_REPORT.md" -ForegroundColor Green
Write-Host "Rollback: git reset --hard $checkpoint" -ForegroundColor Cyan
