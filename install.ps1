# OMNI_SKILLS universal installer (Windows PowerShell wrapper).
# Delegates to install.sh via Git Bash if available; otherwise prints guidance.
#
# One-liner:
#   irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$Agent = ""
)

$ErrorActionPreference = "Stop"

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

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$installSh = Join-Path $scriptDir "install.sh"
$repoUrl   = "https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh"

if (-not (Test-Path $installSh)) {
    # Remote pipe mode — download install.sh to temp.
    $installSh = Join-Path $env:TEMP "omni-install.sh"
    Write-Host "Downloading install.sh ..."
    Invoke-WebRequest -Uri $repoUrl -OutFile $installSh -UseBasicParsing
}

$bash = Find-Bash
if (-not $bash) {
    Write-Host "ERROR: bash not found. Install Git for Windows from https://git-scm.com/download/win" -ForegroundColor Red
    Write-Host "Then re-run: irm $repoUrl.replace('install.sh','install.ps1') | iex"
    exit 1
}

$args = @($installSh)
if ($Force) { $args += "--force" }
if ($Agent)  { $args += @("--agent", $Agent) }

& $bash @args
exit $LASTEXITCODE
