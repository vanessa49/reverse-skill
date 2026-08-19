#requires -Version 5
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SkillRoot = '',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = Join-Path $RepoRoot 'codex-skills\reverse-triage'
if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
    throw "Missing reverse-triage source skill: $source"
}

if ([string]::IsNullOrWhiteSpace($SkillRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $SkillRoot = Join-Path $env:CODEX_HOME 'skills'
    }
    elseif (Test-Path -LiteralPath (Join-Path $HOME '.agents\skills') -PathType Container) {
        $SkillRoot = Join-Path $HOME '.agents\skills'
    }
    else {
        $SkillRoot = Join-Path $HOME '.codex\skills'
    }
}

$destination = Join-Path $SkillRoot 'reverse-triage'
if ((Test-Path -LiteralPath $destination) -and -not $Force) {
    throw "Destination already exists: $destination. Re-run with -Force only if you intend to replace it."
}

if (-not (Test-Path -LiteralPath $SkillRoot)) {
    New-Item -ItemType Directory -Path $SkillRoot -Force | Out-Null
}
if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}
Copy-Item -LiteralPath $source -Destination $destination -Recurse

$resolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Content -LiteralPath (Join-Path $destination 'REPOSITORY_PATH.txt') -Value $resolvedRepo -Encoding ASCII

Write-Output "REVERSE_TRIAGE_INSTALL=PASS"
Write-Output "SKILL_PATH=$destination"
Write-Output "REPOSITORY_PATH=$resolvedRepo"
Write-Output 'Restart Codex or start a new session so skill discovery can refresh.'
