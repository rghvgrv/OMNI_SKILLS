# OMNI_SKILLS — one-shot uninstaller for Windows.
#
# One line:
#   irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/uninstall.ps1 | iex
#
# Removes OMNI_SKILLS from every detected agent. Idempotent.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoColor,
    [string[]]$Only = @()
)

$REMOVED = [System.Collections.Generic.List[string]]::new()
$SKIPPED = [System.Collections.Generic.List[string]]::new()
$FAILED  = [System.Collections.Generic.List[string]]::new()

$useColor = -not $NoColor -and $Host.UI.SupportsVirtualTerminal
function Say  { param($msg) if ($useColor) { Write-Host "`e[0;32m$msg`e[0m" } else { Write-Host $msg } }
function Warn { param($msg) if ($useColor) { Write-Host "`e[0;33m$msg`e[0m" } else { Write-Host $msg } }
function Err  { param($msg) $line = if ($useColor) { "`e[0;31m$msg`e[0m" } else { $msg }; [Console]::Error.WriteLine($line) }
function Note { param($msg) if ($useColor) { Write-Host "`e[2m$msg`e[0m"    } else { Write-Host $msg } }

function Only-Filter { param([string]$id) if ($Only.Count -eq 0) { return $true } return $Only -contains $id }
function Has-Command { param([string]$name) return $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

# ── Claude Code ─────────────────────────────────────────────────────────────
function Remove-Claude {
    if (-not (Only-Filter "claude")) { return }
    if (-not (Has-Command "claude")) { return }
    Say "→ Claude Code"
    if ($DryRun) {
        Note "  [dry-run] claude plugin uninstall omni-skills@omni-skills"
        Note "  [dry-run] claude plugin marketplace remove rghvgrv/OMNI_SKILLS"
        return
    }
    try {
        & claude plugin uninstall "omni-skills@omni-skills" 2>&1 | ForEach-Object { Write-Host "  $_" }
        & claude plugin marketplace remove "rghvgrv/OMNI_SKILLS" 2>&1 | ForEach-Object { Write-Host "  $_" }
        $REMOVED.Add("claude")
    } catch {
        $FAILED.Add("claude")
        Err "  claude uninstall failed: $_"
    }
}

# ── Gemini CLI ──────────────────────────────────────────────────────────────
function Remove-Gemini {
    if (-not (Only-Filter "gemini")) { return }
    if (-not (Has-Command "gemini")) { return }
    Say "→ Gemini CLI"
    if ($DryRun) { Note "  [dry-run] gemini extensions uninstall omni-skills"; return }
    try {
        $output = & gemini extensions uninstall omni-skills 2>&1
        Write-Host $output
        $REMOVED.Add("gemini")
    } catch {
        $msg = $_.Exception.Message
        if ($msg -match "not found|not installed") {
            $SKIPPED.Add("gemini"); Note "  not installed"
        } else {
            $FAILED.Add("gemini"); Err "  gemini uninstall failed: $msg"
        }
    }
}

# ── Cursor ──────────────────────────────────────────────────────────────────
function Remove-Cursor {
    if (-not (Only-Filter "cursor")) { return }
    $dir = "$env:USERPROFILE\.cursor"
    if (-not (Test-Path $dir)) { return }
    Say "→ Cursor"
    $files = @("$dir\rules\clock.mdc", "$dir\rules\system-stats.mdc")
    $any = $false
    foreach ($f in $files) {
        if (Test-Path $f) {
            $any = $true
            if ($DryRun) { Note "  [dry-run] remove $f" }
            else { Remove-Item $f -Force; Note "  removed: $f" }
        }
    }
    if ($any) { $REMOVED.Add("cursor") } else { $SKIPPED.Add("cursor"); Note "  nothing to remove" }
}

# ── Codex ───────────────────────────────────────────────────────────────────
function Remove-Codex {
    if (-not (Only-Filter "codex")) { return }
    $dir = "$env:USERPROFILE\.codex"
    if (-not (Test-Path $dir)) { return }
    Say "→ Codex CLI"
    $skills = @("$dir\skills\clock", "$dir\skills\system-stats")
    $any = $false
    foreach ($s in $skills) {
        if (Test-Path $s) {
            $any = $true
            if ($DryRun) { Note "  [dry-run] remove $s" }
            else { Remove-Item $s -Recurse -Force; Note "  removed: $s" }
        }
    }
    # Strip omni-skills block from AGENTS.md
    $md = "$dir\AGENTS.md"
    if (Test-Path $md) {
        $content = Get-Content $md -Raw
        if ($content -match '<!-- omni-skills:begin -->') {
            $any = $true
            if ($DryRun) {
                Note "  [dry-run] strip omni-skills block from $md"
            } else {
                $stripped = $content -replace '(?s)\n*<!-- omni-skills:begin -->.*?<!-- omni-skills:end -->\n*', "`n"
                Set-Content -Path $md -Value $stripped -NoNewline
                Note "  stripped block from: $md"
            }
        }
    }
    if ($any) { $REMOVED.Add("codex") } else { $SKIPPED.Add("codex"); Note "  nothing to remove" }
}

# ── Generic ─────────────────────────────────────────────────────────────────
function Remove-Generic {
    if (-not (Only-Filter "generic")) { return }
    $dir = "$env:USERPROFILE\.agents"
    if (-not (Test-Path $dir)) { return }
    Say "→ Generic .agents"
    $skills = @("$dir\skills\clock", "$dir\skills\system-stats")
    $any = $false
    foreach ($s in $skills) {
        if (Test-Path $s) {
            $any = $true
            if ($DryRun) { Note "  [dry-run] remove $s" }
            else { Remove-Item $s -Recurse -Force; Note "  removed: $s" }
        }
    }
    if ($any) { $REMOVED.Add("generic") } else { $SKIPPED.Add("generic"); Note "  nothing to remove" }
}

Remove-Claude
Remove-Gemini
Remove-Cursor
Remove-Codex
Remove-Generic

Write-Host "────────────────────────────────────"
if ($REMOVED.Count -gt 0) { Say  "✓ Removed: $($REMOVED -join ', ')" }
if ($SKIPPED.Count -gt 0) { Note "⊘ Nothing to remove: $($SKIPPED -join ', ')" }
if ($FAILED.Count  -gt 0) { Err  "✗ Failed: $($FAILED -join ', ')" }
if ($REMOVED.Count -eq 0 -and $SKIPPED.Count -eq 0 -and $FAILED.Count -eq 0) {
    Warn "No supported agents detected."
}
Write-Host "────────────────────────────────────"

if ($FAILED.Count -gt 0) { exit 1 }
exit 0
