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

$REPO = "rghvgrv/OMNI_SKILLS"
$SKILL_NAMES = @("clock", "system-stats", "min-token")

# UTF-8 console (fixes ΓêÜ/ΓÇª mojibake from claude/gemini/npx output)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

$REMOVED = [System.Collections.Generic.List[string]]::new()
$SKIPPED = [System.Collections.Generic.List[string]]::new()
$FAILED  = [System.Collections.Generic.List[string]]::new()

$useColor = -not $NoColor -and $Host.UI.SupportsVirtualTerminal
$ESC = [char]27
function Say  { param($msg) if ($useColor) { Write-Host "$ESC[0;32m$msg$ESC[0m" } else { Write-Host $msg } }
function Warn { param($msg) if ($useColor) { Write-Host "$ESC[0;33m$msg$ESC[0m" } else { Write-Host $msg } }
function Err  { param($msg) $line = if ($useColor) { "$ESC[0;31m$msg$ESC[0m" } else { $msg }; [Console]::Error.WriteLine($line) }
function Note { param($msg) if ($useColor) { Write-Host "$ESC[2m$msg$ESC[0m"    } else { Write-Host $msg } }

function Only-Filter { param([string]$id) if ($Only.Count -eq 0) { return $true } return $Only -contains $id }
function Has-Command { param([string]$name) return $null -ne (Get-Command $name -ErrorAction SilentlyContinue) }

# ── Claude Code ─────────────────────────────────────────────────────────────
function Remove-Claude {
    if (-not (Only-Filter "claude")) { return }
    if (-not (Has-Command "claude")) { return }
    Say "→ Claude Code"
    if ($DryRun) {
        Note "  [dry-run] claude plugin uninstall omni-skills@omni-skills"
        Note "  [dry-run] claude plugin marketplace remove $REPO"
        return
    }
    try {
        & claude plugin uninstall "omni-skills@omni-skills" 2>&1 | ForEach-Object { Write-Host "  $_" }
        # Marketplace registered under name "omni-skills", not full repo path
        & claude plugin marketplace remove "omni-skills" 2>&1 | ForEach-Object { Write-Host "  $_" }
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

# ── Generic: npx skills remove ──────────────────────────────────────────────
function Remove-Via-Skills {
    param(
        [string]$id,
        [string]$label,
        [string]$detect,
        [string]$profile
    )
    if (-not (Only-Filter $id)) { return }

    $detected = $false
    if ($detect.StartsWith("cmd:")) { $detected = Has-Command $detect.Substring(4) }
    elseif ($detect.StartsWith("dir:")) { $detected = Test-Path $detect.Substring(4) }
    if (-not $detected) { return }

    Say "→ $label"
    if (-not (Has-Command "node")) {
        Warn "  node/npx not found — skipping"
        $SKIPPED.Add($id); return
    }

    if ($DryRun) {
        foreach ($s in $SKILL_NAMES) {
            Note "  [dry-run] npx -y skills remove $s -a $profile --yes --global"
        }
        return
    }

    $anyRemoved = $false
    foreach ($s in $SKILL_NAMES) {
        try {
            & npx -y skills remove $s -a $profile --yes --global 2>&1 | ForEach-Object { Write-Host "  $_" }
            if ($LASTEXITCODE -eq 0) { $anyRemoved = $true }
        } catch {
            Note "  ${s}: $_"
        }
    }
    if ($anyRemoved) { $REMOVED.Add($id) } else { $SKIPPED.Add($id); Note "  nothing matched" }
}

Remove-Claude
Remove-Gemini

Remove-Via-Skills "codex"       "Codex CLI + GUI"              "cmd:codex" "codex"
Remove-Via-Skills "copilot"     "GitHub Copilot CLI"           "cmd:gh"    "github-copilot"
Remove-Via-Skills "vscode"      "VS Code (Copilot)"            "cmd:code"  "github-copilot"
Remove-Via-Skills "antigravity" "Gemini GUI (Antigravity)"     "dir:$env:USERPROFILE\.antigravity" "antigravity"

# Direct cleanup of ~/.agents/skills/<skill> (regardless of agent) ────────────
$globalSkills = "$env:USERPROFILE\.agents\skills"
foreach ($s in $SKILL_NAMES) {
    $p = Join-Path $globalSkills $s
    if (Test-Path $p) {
        if ($DryRun) { Note "  [dry-run] remove $p" }
        else { Remove-Item $p -Recurse -Force; Note "  removed: $p" }
    }
}

Write-Host "────────────────────────────────────"
if ($REMOVED.Count -gt 0) { Say  "✓ Removed: $($REMOVED -join ', ')" }
if ($SKIPPED.Count -gt 0) { Note "⊘ Nothing to remove / not installed: $($SKIPPED -join ', ')" }
if ($FAILED.Count  -gt 0) { Err  "✗ Failed: $($FAILED -join ', ')" }
if ($REMOVED.Count -eq 0 -and $SKIPPED.Count -eq 0 -and $FAILED.Count -eq 0) {
    Warn "No supported agents detected."
}
Write-Host "────────────────────────────────────"

if ($FAILED.Count -gt 0) {
    $global:LASTEXITCODE = 1
    Err "Done with errors."
} else {
    $global:LASTEXITCODE = 0
    Say "Done."
}
