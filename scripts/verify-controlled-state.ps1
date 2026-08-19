#requires -Version 5
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

$criticalPaths = @($lock.critical_upstream_blobs.PSObject.Properties | ForEach-Object { $_.Name })
$allowedOverlayChanges = @('AGENTS.md')
$mustRemainUpstream = @($criticalPaths | Where-Object { $_ -notin $allowedOverlayChanges })

foreach ($path in $mustRemainUpstream) {
    $expected = [string]$lock.critical_upstream_blobs.$path
    $actual = (& $git.Source -C $RepoRoot rev-parse "$approved`:$path" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$actual)) {
        throw "Cannot resolve approved upstream blob for $path"
    }
    if ([string]$actual -ne $expected) {
        throw "Lock metadata mismatch for $path. Expected $expected, approved commit contains $actual"
    }

    $changed = @(& $git.Source -C $RepoRoot diff --name-only $approved -- $path)
    if ($LASTEXITCODE -ne 0) {
        throw "git diff failed for $path"
    }
    if ($changed.Count -gt 0) {
        throw "Critical upstream file drifted after audit: $path"
    }
}

$workingChanges = @(& $git.Source -C $RepoRoot status --porcelain -- @($mustRemainUpstream))
if ($LASTEXITCODE -ne 0) {
    throw 'git status failed while checking critical paths'
}
if ($workingChanges.Count -gt 0) {
    throw "Uncommitted changes exist in critical upstream paths: $($workingChanges -join '; ')"
}

Write-Output "CONTROLLED_STATE=PASS"
Write-Output "APPROVED_UPSTREAM=$approved"
Write-Output "MODE=$($lock.verdict)"
