[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PayloadPath,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Commit
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'dependencies.manifest.json') | ConvertFrom-Json
$contract = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'cmake\material-phone\squirrel-contract.json') | ConvertFrom-Json
if ($manifest.signing.allowed -ne $false -or $contract.signing.allowed -ne $false) {
    throw 'Code signing is prohibited; the packaging contract must require unsigned output.'
}
if (-not (Test-Path -LiteralPath $PayloadPath -PathType Container)) { throw "Payload directory is missing: $PayloadPath" }
$payloadExecutables = @(Get-ChildItem -LiteralPath $PayloadPath -Filter '*.exe' -File -Recurse)
if ($payloadExecutables.Count -eq 0) { throw 'The application payload contains no executable.' }

$nuget = Get-Command nuget.exe -ErrorAction SilentlyContinue
if (-not $nuget) { throw 'nuget.exe is unavailable after dependency bootstrap.' }
$packageRoot = Join-Path $repoRoot '.tools\squirrel'
$squirrelPackage = [string]$manifest.nuget.package
$squirrelVersion = [string]$manifest.nuget.version
$squirrelExe = Join-Path $packageRoot "$squirrelPackage.$squirrelVersion\tools\Squirrel.exe"
if (-not (Test-Path -LiteralPath $squirrelExe)) {
    Write-Host "[installer] Fetching $squirrelPackage $squirrelVersion from $($manifest.nuget.source)."
    & $nuget.Source install $squirrelPackage -Version $squirrelVersion -Source $manifest.nuget.source -OutputDirectory $packageRoot -NonInteractive -DirectDownload | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "NuGet could not obtain Squirrel.Windows (exit $LASTEXITCODE)." }
}
if (-not (Test-Path -LiteralPath $squirrelExe)) { throw "Squirrel.exe is missing: $squirrelExe" }

$stage = Join-Path $repoRoot 'build\squirrel-stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'payload'), $OutputPath | Out-Null
Copy-Item -Path (Join-Path $PayloadPath '*') -Destination (Join-Path $stage 'payload') -Recurse -Force

$template = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'cmake\material-phone\MaterialPhone.nuspec.in')
$nuspec = $template.Replace('@PACKAGE_ID@', [string]$contract.packageId).Replace('@PACKAGE_VERSION@', $Version)
$nuspecPath = Join-Path $stage 'MaterialPhone.nuspec'
Set-Content -LiteralPath $nuspecPath -Value $nuspec -Encoding utf8
& $nuget.Source pack $nuspecPath -OutputDirectory $stage -NoPackageAnalysis -NonInteractive | Out-Host
if ($LASTEXITCODE -ne 0) { throw "NuGet payload packaging failed (exit $LASTEXITCODE)." }
$basePackage = Get-ChildItem -LiteralPath $stage -Filter '*.nupkg' -File | Select-Object -First 1
if (-not $basePackage) { throw 'NuGet reported success without producing a package.' }

# Keeping prior full packages in the release directory lets Squirrel emit a delta.
& $squirrelExe --releasify $basePackage.FullName --releaseDir $OutputPath --no-msi | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Squirrel releasify failed (exit $LASTEXITCODE)." }

$setup = Join-Path $OutputPath 'Setup.exe'
$releases = Join-Path $OutputPath 'RELEASES'
$fullPackages = @(Get-ChildItem -LiteralPath $OutputPath -Filter '*-full.nupkg' -File)
if (-not (Test-Path -LiteralPath $setup)) { throw 'Squirrel did not produce Setup.exe.' }
if (-not (Test-Path -LiteralPath $releases)) { throw 'Squirrel did not produce RELEASES.' }
if ($fullPackages.Count -eq 0) { throw 'Squirrel did not produce a full .nupkg.' }
$releaseIndex = Get-Content -Raw -LiteralPath $releases
foreach ($package in $fullPackages) {
    if (-not $releaseIndex.Contains($package.Name)) { throw "RELEASES does not reference $($package.Name)." }
}

$signature = Get-AuthenticodeSignature -LiteralPath $setup
if ([string]$signature.Status -ne [string]$contract.signing.requiredAuthenticodeStatus) {
    throw "Setup.exe must be unsigned, but Authenticode status is $($signature.Status)."
}
$provenance = [ordered]@{
    schemaVersion = 1
    commit = $Commit
    version = $Version
    unsigned = $true
    setupSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
    fullPackages = @($fullPackages | ForEach-Object { $_.Name })
    deltaPackages = @(Get-ChildItem -LiteralPath $OutputPath -Filter '*-delta.nupkg' -File | ForEach-Object { $_.Name })
}
$provenance | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputPath 'build-provenance.json') -Encoding utf8
Write-Host "[installer] Squirrel contract verified for commit $Commit. Setup.exe is unsigned."
