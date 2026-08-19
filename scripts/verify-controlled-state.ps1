#requires -Version 5
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    else {
        throw 'Cannot determine repository root. Re-run with -RepoRoot <path>.'
    }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$lockPath = Join-Path $RepoRoot '.controlled\upstream-lock.json'
if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    throw "Missing controlled lock file: $lockPath"
}

$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
$approved = [string]$lock.approved_upstream_commit
if ([string]::IsNullOrWhiteSpace($approved)) {
    throw 'approved_upstream_commit is empty'
}

$git = Get-Command git -ErrorAction Stop
& $git.Source -C $RepoRoot cat-file -e "$approved`^{commit}"
if ($LASTEXITCODE -ne 0) {
    throw "Approved upstream commit is not present locally: $approved"
}

& $git.Source -C $RepoRoot merge-base --is-ancestor $approved HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Current HEAD is not descended from approved upstream commit: $approved"
}

$criticalProperties = @($lock.critical_upstream_blobs.PSObject.Properties)
$criticalPaths = @($criticalProperties | ForEach-Object { $_.Name })
$allowedOverlayChanges = @('AGENTS.md')
$mustRemainUpstream = @($criticalPaths | Where-Object { $_ -notin $allowedOverlayChanges })

foreach ($path in $mustRemainUpstream) {
    $property = $criticalProperties | Where-Object { $_.Name -eq $path } | Select-Object -First 1
    if ($null -eq $property) {
        throw "Missing lock metadata for $path"
    }
    $expected = [string]$property.Value

    $treeLines = @(& $git.Source -C $RepoRoot ls-tree $approved -- $path 2>$null)
    $treeExit = $LASTEXITCODE
    if ($treeExit -ne 0 -or $treeLines.Count -ne 1) {
        throw "Cannot resolve approved upstream blob for $path"
    }
    $parts = @(([string]$treeLines[0]) -split '\s+')
    if ($parts.Count -lt 3 -or $parts[1] -ne 'blob') {
        throw "Unexpected git ls-tree output for ${path}: $($treeLines[0])"
    }
    $actual = [string]$parts[2]
    if ($actual -ne $expected) {
        throw "Lock metadata mismatch for $path. Expected $expected, approved commit contains $actual"
    }

    $changed = @(& $git.Source -C $RepoRoot diff --name-only $approved -- $path)
    $diffExit = $LASTEXITCODE
    if ($diffExit -ne 0) {
        throw "git diff failed for $path"
    }
    if ($changed.Count -gt 0) {
        throw "Critical upstream file drifted after audit: $path"
    }
}

$workingChanges = @(& $git.Source -C $RepoRoot status --porcelain -- $mustRemainUpstream)
$statusExit = $LASTEXITCODE
if ($statusExit -ne 0) {
    throw 'git status failed while checking critical paths'
}
if ($workingChanges.Count -gt 0) {
    throw "Uncommitted changes exist in critical upstream paths: $($workingChanges -join '; ')"
}

Write-Output "CONTROLLED_STATE=PASS"
Write-Output "APPROVED_UPSTREAM=$approved"
Write-Output "MODE=$($lock.verdict)"
