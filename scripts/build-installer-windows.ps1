[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$Version = $(if ($env:MATERIAL_PHONE_VERSION) { $env:MATERIAL_PHONE_VERSION } else { '0.0.0-local' })
)

$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host '[installer] Ensuring the real application payload is current.'
& (Join-Path $repoRoot 'build.bat') /s
if ($LASTEXITCODE -ne 0) { throw "Application build failed (exit $LASTEXITCODE)." }

$expectedCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
$buildRoot = Join-Path $repoRoot "build\windows\$expectedCommit"
$payload = Join-Path $buildRoot 'OUTPUT'
$builtCommitPath = Join-Path $buildRoot 'build-commit.txt'
if (-not (Test-Path -LiteralPath $builtCommitPath)) { throw 'Build provenance marker is missing.' }
$builtCommit = (Get-Content -Raw -LiteralPath $builtCommitPath).Trim()
if ($builtCommit -ne $expectedCommit) {
    throw "Payload commit $builtCommit does not match intended commit $expectedCommit."
}

$payloadProvenancePath = Join-Path $buildRoot 'payload-provenance.json'
if (-not (Test-Path -LiteralPath $payloadProvenancePath -PathType Leaf)) { throw 'Payload byte provenance is missing.' }
$releaseDir = Join-Path $repoRoot "build\release\$expectedCommit\$Version"
& (Join-Path $PSScriptRoot 'package-squirrel.ps1') -PayloadPath $payload -PayloadProvenancePath $payloadProvenancePath -OutputPath $releaseDir -Version $Version -Commit $expectedCommit
if ($LASTEXITCODE -ne 0) { throw "Squirrel packaging failed (exit $LASTEXITCODE)." }

$setup = Join-Path $releaseDir 'Setup.exe'
$provenance = Get-Content -Raw -LiteralPath (Join-Path $releaseDir 'build-provenance.json') | ConvertFrom-Json
if ([string]$provenance.commit -ne $expectedCommit -or $provenance.unsigned -ne $true) { throw 'Installer provenance does not bind to the intended unsigned commit.' }
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $setup
$elapsed = (Get-Date) - $startedAt
Write-Host ("[installer] Unsigned Squirrel.Windows installer built in {0:hh\:mm\:ss}." -f $elapsed)
Write-Host "[installer] Artifact: $setup"
Write-Host "[installer] SHA-256: $($hash.Hash.ToLowerInvariant())"
