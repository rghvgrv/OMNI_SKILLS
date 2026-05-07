# OMNI_SKILLS universal installer (Windows PowerShell wrapper).
# Clones repo to temp, then delegates to install.sh via Git Bash.
#
# One-liner:
#   irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$Agent = "",
    [string]$Ref = "main"
)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/rghvgrv/OMNI_SKILLS.git"
$RawBase = "https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/$Ref"

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
    $candidates = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

# Detect remote-pipe vs local-clone execution.
# When piped via `irm | iex`, $PSScriptRoot is empty AND $PSCommandPath is null.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$localInstallSh = Join-Path $scriptDir "install.sh"
$localSkills    = Join-Path $scriptDir "skills"
$isLocalRepo    = (Test-Path $localInstallSh) -and (Test-Path $localSkills)

if ($isLocalRepo) {
    $repoRoot = $scriptDir
    Write-Host "Using local repo: $repoRoot"
} else {
    $git = Find-Git
    $repoRoot = Join-Path $env:TEMP ("omni-skills-" + [guid]::NewGuid().ToString("N"))

    if ($git) {
        Write-Host "Cloning $RepoUrl (ref: $Ref) -> $repoRoot"
        & $git clone --depth 1 --branch $Ref $RepoUrl $repoRoot
        if ($LASTEXITCODE -ne 0) {
            throw "git clone failed (exit $LASTEXITCODE)"
        }
    } else {
        # Fallback: download tarball via Invoke-WebRequest + tar (Windows 10+).
        Write-Host "git not found — downloading tarball"
        $tarUrl = "https://codeload.github.com/rghvgrv/OMNI_SKILLS/tar.gz/refs/heads/$Ref"
        $tarPath = Join-Path $env:TEMP ("omni-skills-" + [guid]::NewGuid().ToString("N") + ".tar.gz")
        Invoke-WebRequest -Uri $tarUrl -OutFile $tarPath -UseBasicParsing
        New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
        & tar.exe -xzf $tarPath -C $repoRoot --strip-components=1
        if ($LASTEXITCODE -ne 0) {
            throw "tar extract failed (exit $LASTEXITCODE). Install Git for Windows: https://git-scm.com/download/win"
        }
        Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
    }
}

$installSh = Join-Path $repoRoot "install.sh"
if (-not (Test-Path $installSh)) {
    throw "install.sh missing in $repoRoot"
}

$bash = Find-Bash
if (-not $bash) {
    Write-Host "ERROR: bash not found. Install Git for Windows: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# Convert Windows path to Git-Bash MSYS path (C:\foo -> /c/foo).
function Convert-ToMsysPath([string]$p) {
    $full = (Resolve-Path $p).Path
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        $drive = $matches[1].ToLower()
        $rest  = $matches[2] -replace '\\', '/'
        return "/$drive/$rest"
    }
    return $full -replace '\\', '/'
}

$shArgs = @((Convert-ToMsysPath $installSh))
if ($Force) { $shArgs += "--force" }
if ($Agent) { $shArgs += @("--agent", $Agent) }

& $bash @shArgs
$code = $LASTEXITCODE

# Cleanup temp clone if we created it.
if (-not $isLocalRepo) {
    Remove-Item $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit $code
