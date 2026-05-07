# OMNI_SKILLS — multi-agent installer for Windows.
#
# One line:
#   irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
#
# Detects which AI coding agents are on the machine and installs OMNI_SKILLS
# globally for each one via that agent's native plugin/extension manager.
# Falls back to file-copy install for agents without a plugin manager.

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$List,
    [switch]$NoColor,
    [switch]$Force,
    [string[]]$Only = @(),
    [switch]$Help
)

$REPO       = "rghvgrv/OMNI_SKILLS"
$REPO_URL   = "https://github.com/$REPO"
$ASSETS_REF = if ($env:OMNI_REF) { $env:OMNI_REF } else { "main" }

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
  -Force            Overwrite existing copies (file-copy agents only).
  -Help             Show this help and exit.

ENVIRONMENT
  OMNI_REF          Git ref used for fallback installs. Default: main

SUPPORTED AGENTS
  Native plugin manager (global):
    claude       Claude Code         claude plugin marketplace add + install
    gemini       Gemini CLI          gemini extensions install
  File-copy fallback (per-user):
    cursor       Cursor              ~/.cursor/rules/<skill>.mdc
    codex        Codex CLI           ~/.codex/skills/<skill>/
    generic      Generic .agents     ~/.agents/skills/<skill>/

EXAMPLES
  install.ps1                        # auto-detect all agents
  install.ps1 -Only claude
  install.ps1 -Only claude -Only gemini
  install.ps1 -DryRun
'@

if ($Help -or $List) { Write-Host $HELP_TEXT; exit 0 }

# ── Color setup ──────────────────────────────────────────────────────────────
$useColor = -not $NoColor -and $Host.UI.SupportsVirtualTerminal

function Say  { param($msg) if ($useColor) { Write-Host "`e[0;32m$msg`e[0m" } else { Write-Host $msg } }
function Warn { param($msg) if ($useColor) { Write-Host "`e[0;33m$msg`e[0m" } else { Write-Host $msg } }
function Err  { param($msg) $line = if ($useColor) { "`e[0;31m$msg`e[0m" } else { $msg }; [Console]::Error.WriteLine($line) }
function Note { param($msg) if ($useColor) { Write-Host "`e[2m$msg`e[0m"    } else { Write-Host $msg } }

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

# ── Fallback: file-copy via install.sh (cursor/codex/generic) ────────────────
function Find-Bash {
    $candidates = @(
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    $cmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    return $null
}

function Find-Git {
    $cmd = Get-Command git -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    return $null
}

function Convert-ToMsysPath([string]$p) {
    $full = (Resolve-Path $p).Path
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        $drive = $matches[1].ToLower()
        $rest  = $matches[2] -replace '\\', '/'
        return "/$drive/$rest"
    }
    return $full -replace '\\', '/'
}

function Install-Fallback-Agents {
    $fallbackTargets = @()
    if ((Only-Filter "cursor")  -and (Test-Path "$env:USERPROFILE\.cursor"))  { $fallbackTargets += "cursor" }
    if ((Only-Filter "codex")   -and (Test-Path "$env:USERPROFILE\.codex"))   { $fallbackTargets += "codex" }
    if ((Only-Filter "generic") -and (Test-Path "$env:USERPROFILE\.agents")) { $fallbackTargets += "generic" }

    if ($fallbackTargets.Count -eq 0) { return }

    Say "→ File-copy fallback for: $($fallbackTargets -join ', ')"

    $bash = Find-Bash
    if (-not $bash) {
        Warn "  bash not found — install Git for Windows to enable cursor/codex/generic"
        foreach ($t in $fallbackTargets) { $SKIPPED.Add($t) }
        Write-Host ""
        return
    }

    # Detect script source: local checkout vs remote pipe.
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $localInstallSh = Join-Path $scriptDir "install.sh"
    $localSkills    = Join-Path $scriptDir "skills"

    if ((Test-Path $localInstallSh) -and (Test-Path $localSkills)) {
        $repoRoot = $scriptDir
        $isTemp = $false
    } else {
        $git = Find-Git
        $repoRoot = Join-Path $env:TEMP ("omni-skills-" + [guid]::NewGuid().ToString("N"))
        $isTemp = $true

        if ($git) {
            if ($DryRun) {
                Note "  [dry-run] git clone --depth 1 --branch $ASSETS_REF $REPO_URL $repoRoot"
            } else {
                & $git clone --depth 1 --branch $ASSETS_REF "$REPO_URL.git" $repoRoot 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Err "  git clone failed (exit $LASTEXITCODE) — skipping fallback"
                    foreach ($t in $fallbackTargets) { $FAILED.Add($t) }
                    Write-Host ""
                    return
                }
            }
        } else {
            $tarUrl = "https://codeload.github.com/$REPO/tar.gz/refs/heads/$ASSETS_REF"
            $tarPath = Join-Path $env:TEMP ("omni-skills-" + [guid]::NewGuid().ToString("N") + ".tar.gz")
            if ($DryRun) {
                Note "  [dry-run] download + extract tarball from $tarUrl"
            } else {
                try {
                    Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath -UseBasicParsing
                    New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
                    & tar.exe -xzf $tarPath -C $repoRoot --strip-components=1
                    Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
                } catch {
                    Err "  tarball fetch failed: $_ — skipping fallback"
                    foreach ($t in $fallbackTargets) { $FAILED.Add($t) }
                    Write-Host ""
                    return
                }
            }
        }
    }

    foreach ($agent in $fallbackTargets) {
        if ($DryRun) {
            Note "  [dry-run] bash install.sh --agent $agent"
            $WOULD_INSTALL.Add($agent)
            continue
        }
        $installSh = Join-Path $repoRoot "install.sh"
        $shArgs = @((Convert-ToMsysPath $installSh), "--agent", $agent)
        if ($Force) { $shArgs += "--force" }
        & $bash @shArgs
        if ($LASTEXITCODE -eq 0) { $INSTALLED.Add($agent) } else { $FAILED.Add($agent) }
    }

    if ($isTemp -and -not $DryRun) {
        Remove-Item $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host ""
}

# ── Run installs ─────────────────────────────────────────────────────────────
Install-Claude
Install-Gemini
Install-Fallback-Agents

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
        Note "Install Claude Code, Gemini CLI, Cursor, or Codex first."
    }
}
Write-Host "────────────────────────────────────"

if ($FAILED.Count -gt 0) { exit 1 }
exit 0
