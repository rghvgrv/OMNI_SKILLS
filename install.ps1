# OMNI_SKILLS — multi-agent installer for Windows.
#
# One line:
#   irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
#
# Detects which AI coding agents are on the machine and installs OMNI_SKILLS
# globally for each via that agent's native plugin/extension manager, or via
# `npx skills add` for agents without one. No file copying.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$List,
    [switch]$NoColor,
    [string[]]$Only = @(),
    [switch]$Help
)

$REPO     = "rghvgrv/OMNI_SKILLS"
$REPO_URL = "https://github.com/$REPO"

$INSTALLED     = [System.Collections.Generic.List[string]]::new()
$SKIPPED       = [System.Collections.Generic.List[string]]::new()
$FAILED        = [System.Collections.Generic.List[string]]::new()
$WOULD_INSTALL = [System.Collections.Generic.List[string]]::new()

$HELP_TEXT = @'
OMNI_SKILLS installer (Windows)

USAGE
  install.ps1 [flags]
  irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex

FLAGS
  -DryRun           Print what would run, do nothing.
  -Only <agent>     Install only for the named agent. Repeatable.
  -List             Print supported agents and exit.
  -NoColor          Disable ANSI color codes.
  -Help             Show this help and exit.

SUPPORTED AGENTS
  Native:
    claude       Claude Code CLI + App      claude plugin marketplace add + install
    gemini       Gemini CLI                 gemini extensions install
  Via npx skills add:
    codex        Codex CLI + GUI
    copilot      GitHub Copilot CLI + VS Code
    antigravity  Gemini GUI (Antigravity)

EXAMPLES
  install.ps1                        # auto-detect all agents
  install.ps1 -Only claude
  install.ps1 -Only copilot -Only codex
  install.ps1 -DryRun
'@

if ($Help -or $List) { Write-Host $HELP_TEXT; exit 0 }

# ── Color setup ──────────────────────────────────────────────────────────────
$useColor = -not $NoColor -and $Host.UI.SupportsVirtualTerminal
$ESC = [char]27

function Say  { param($msg) if ($useColor) { Write-Host "$ESC[0;32m$msg$ESC[0m" } else { Write-Host $msg } }
function Warn { param($msg) if ($useColor) { Write-Host "$ESC[0;33m$msg$ESC[0m" } else { Write-Host $msg } }
function Err  { param($msg) $line = if ($useColor) { "$ESC[0;31m$msg$ESC[0m" } else { $msg }; [Console]::Error.WriteLine($line) }
function Note { param($msg) if ($useColor) { Write-Host "$ESC[2m$msg$ESC[0m"    } else { Write-Host $msg } }

# ── Helpers ──────────────────────────────────────────────────────────────────
function Only-Filter {
    param([string]$id)
    if ($Only.Count -eq 0) { return $true }
    return $Only -contains $id
}

function Has-Command {
    param([string]$name)
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Ensure-Node {
    if (Has-Command "node") { return $true }
    Warn "  node/npx not found — skipping (install Node.js from https://nodejs.org)"
    return $false
}

function Try-Run {
    param([scriptblock]$block, [string]$description)
    if ($DryRun) { Note "  [dry-run] $description"; return $true }
    try { & $block; return ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) }
    catch { return $false }
}

# ── Native: Claude Code ──────────────────────────────────────────────────────
function Install-Claude {
    if (-not (Only-Filter "claude")) { return }
    if (-not (Has-Command "claude")) { return }
    Say "→ Claude Code detected"

    if ($DryRun) {
        Note "  [dry-run] claude plugin marketplace add $REPO"
        Note "  [dry-run] claude plugin install omni-skills@omni-skills"
        $WOULD_INSTALL.Add("claude")
        Write-Host ""
        return
    }

    try {
        & claude plugin marketplace add $REPO 2>&1 | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE -ne 0) { throw "marketplace add failed (exit $LASTEXITCODE)" }
        & claude plugin install "omni-skills@omni-skills" 2>&1 | ForEach-Object { Write-Host "  $_" }
        if ($LASTEXITCODE -ne 0) { throw "plugin install failed (exit $LASTEXITCODE)" }
        $INSTALLED.Add("claude")
    } catch {
        $FAILED.Add("claude")
        Err "  claude plugin install failed: $_"
    }
    Write-Host ""
}

# ── Native: Gemini CLI ───────────────────────────────────────────────────────
function Install-Gemini {
    if (-not (Only-Filter "gemini")) { return }
    if (-not (Has-Command "gemini")) { return }
    Say "→ Gemini CLI detected"

    $integrityFile = "$env:USERPROFILE\.gemini\extension_integrity.json"
    if (Test-Path $integrityFile) {
        try { $null = Get-Content $integrityFile -Raw | ConvertFrom-Json -ErrorAction Stop }
        catch {
            Note "  clearing corrupted Gemini integrity store"
            if (-not $DryRun) { Remove-Item -Force $integrityFile }
        }
    }

    if ($DryRun) {
        Note "  [dry-run] gemini extensions install --consent $REPO_URL"
        $WOULD_INSTALL.Add("gemini")
        Write-Host ""
        return
    }

    try {
        $output = & gemini extensions install --consent $REPO_URL 2>&1
        Write-Host $output
        $INSTALLED.Add("gemini")
    } catch {
        $output = $_.Exception.Message
        Write-Host $output
        if ($output -match "already installed") {
            Note "  Gemini extension already installed; continuing"
            $INSTALLED.Add("gemini")
        } else {
            $FAILED.Add("gemini")
            Err "  gemini extensions install failed"
        }
    }
    Write-Host ""
}

# ── Generic: npx skills add ──────────────────────────────────────────────────
function Install-Via-Skills {
    param(
        [string]$id,
        [string]$label,
        [string]$detect,
        [string]$profile
    )

    if (-not (Only-Filter $id)) { return }

    $detected = $false
    if ($detect.StartsWith("cmd:")) {
        $cmd = $detect.Substring(4)
        $detected = Has-Command $cmd
    } elseif ($detect.StartsWith("dir:")) {
        $dir = $detect.Substring(4)
        $detected = Test-Path $dir
    } else {
        Warn "  BUG: unknown detect_expr '$detect' for agent '$id'"
        return
    }

    if (-not $detected) { return }

    Say "→ $label detected"
    if (-not (Ensure-Node)) { $SKIPPED.Add($id); Write-Host ""; return }

    $ok = Try-Run {
        & npx -y skills add $REPO -a $profile --yes --global
    } "npx -y skills add $REPO -a $profile --yes --global"

    if ($ok) {
        if ($DryRun) { $WOULD_INSTALL.Add($id) } else { $INSTALLED.Add($id) }
    } else {
        $FAILED.Add($id)
        Err "  npx skills add failed (profile: $profile)"
    }
    Write-Host ""
}

# ── Run installs ─────────────────────────────────────────────────────────────
Install-Claude
Install-Gemini

Install-Via-Skills "codex"       "Codex CLI + GUI"             "cmd:codex" "codex"
Install-Via-Skills "copilot"     "GitHub Copilot CLI + VS Code" "cmd:gh"   "github-copilot"
Install-Via-Skills "antigravity" "Gemini GUI (Antigravity)"    "dir:$env:USERPROFILE\.antigravity" "antigravity"

# ── Summary ──────────────────────────────────────────────────────────────────
Write-Host "────────────────────────────────────"
if ($INSTALLED.Count     -gt 0) { Say  "✓ Installed: $($INSTALLED -join ', ')" }
if ($WOULD_INSTALL.Count -gt 0) { Note "~ Would install (dry-run): $($WOULD_INSTALL -join ', ')" }
if ($SKIPPED.Count       -gt 0) { Warn "⊘ Skipped (missing dep): $($SKIPPED -join ', ')" }
if ($FAILED.Count        -gt 0) { Err  "✗ Failed: $($FAILED -join ', ')" }

if ($INSTALLED.Count -eq 0 -and $FAILED.Count -eq 0 -and $SKIPPED.Count -eq 0 -and $WOULD_INSTALL.Count -eq 0) {
    if ($Only.Count -gt 0) {
        Warn "None of the specified agents were detected on this machine."
    } else {
        Warn "No supported agents detected."
        Note "Run 'install.ps1 -List' to see all supported agents."
    }
}
Write-Host "────────────────────────────────────"

if ($FAILED.Count -gt 0) {
    $global:LASTEXITCODE = 1
    Err "Done with errors."
} else {
    $global:LASTEXITCODE = 0
    Say "Done."
}
