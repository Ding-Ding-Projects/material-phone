[CmdletBinding()]
param(
    [string]$PayloadPath,
    [string]$PayloadProvenancePath,
    [string]$OutputPath,
    [string]$Version,
    [string]$Commit,
    [switch]$ValidateReleaseFixtureOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'dependencies.manifest.json') | ConvertFrom-Json
$contract = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'cmake\material-phone\squirrel-contract.json') | ConvertFrom-Json

function Assert-UnsignedExecutable([string]$Path) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ([string]$signature.Status -ne [string]$contract.signing.requiredAuthenticodeStatus) {
        throw "Executable must remain unsigned: $Path ($($signature.Status))."
    }
}

function Assert-ExactOwnedPath([string]$ActualPath, [string]$ExpectedPath, [string]$Label) {
    $actual = [IO.Path]::GetFullPath($ActualPath).TrimEnd('\')
    $expected = [IO.Path]::GetFullPath($ExpectedPath).TrimEnd('\')
    if (-not $actual.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label is outside its exact owned staging path: $actual" }
}

function Assert-PayloadProvenance([string]$Root, [string]$ProvenancePath, [string]$ExpectedCommit) {
    if (-not (Test-Path -LiteralPath $ProvenancePath -PathType Leaf)) { throw "Payload provenance is missing: $ProvenancePath" }
    $provenance = Get-Content -Raw -LiteralPath $ProvenancePath | ConvertFrom-Json
    if ([string]$provenance.commit -ne $ExpectedCommit) { throw 'Payload provenance commit does not match the packaging commit.' }
    if ([string]$provenance.applicationExecutable -ne [string]$contract.applicationExecutableRelativePath) { throw 'Payload provenance names the wrong application executable.' }
    $expected = @{}
    foreach ($record in @($provenance.files)) {
        $relative = ([string]$record.path).Replace('\', '/')
        if ($relative -match '(^|/)\.\.(/|$)' -or [IO.Path]::IsPathRooted($relative)) { throw "Unsafe payload provenance path: $relative" }
        if ($expected.ContainsKey($relative)) { throw "Duplicate payload provenance path: $relative" }
        $expected[$relative] = $record
    }
    $actualFiles = @(Get-ChildItem -LiteralPath $Root -File -Recurse)
    if ($actualFiles.Count -ne $expected.Count) { throw 'Payload file count does not match its provenance.' }
    foreach ($file in $actualFiles) {
        $relative = $file.FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\', '/')
        if (-not $expected.ContainsKey($relative)) { throw "Payload file is absent from provenance: $relative" }
        $record = $expected[$relative]
        if ([int64]$record.size -ne $file.Length) { throw "Payload size mismatch: $relative" }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        if ($hash -ne ([string]$record.sha256).ToLowerInvariant()) { throw "Payload SHA-256 mismatch: $relative" }
    }
    $expectedExecutable = Join-Path $Root ([string]$contract.applicationExecutableRelativePath).Replace('/', '\')
    if (-not (Test-Path -LiteralPath $expectedExecutable -PathType Leaf)) { throw "Exact Material Phone executable is missing: $expectedExecutable" }
    foreach ($executable in @(Get-ChildItem -LiteralPath $Root -Filter '*.exe' -File -Recurse)) { Assert-UnsignedExecutable $executable.FullName }
    return $provenance
}

function Get-ReleaseRecords([string]$ReleaseIndexPath) {
    if (-not (Test-Path -LiteralPath $ReleaseIndexPath -PathType Leaf)) { throw "RELEASES is missing: $ReleaseIndexPath" }
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($line in [IO.File]::ReadAllLines($ReleaseIndexPath)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -notmatch '^([0-9A-Fa-f]{40})\s+([^\s\\/]+\.nupkg)\s+([0-9]+)$') { throw "Malformed RELEASES record: $line" }
        $records.Add([pscustomobject]@{ sha1 = $Matches[1].ToLowerInvariant(); file = $Matches[2]; size = [int64]$Matches[3] })
    }
    if ($records.Count -eq 0) { throw 'RELEASES contains no package records.' }
    return $records.ToArray()
}

function Test-ReleaseIndex([string]$ReleaseDirectory) {
    $records = @(Get-ReleaseRecords (Join-Path $ReleaseDirectory 'RELEASES'))
    $packages = @(Get-ChildItem -LiteralPath $ReleaseDirectory -Filter '*.nupkg' -File)
    if ($packages.Count -ne $records.Count) { throw 'RELEASES record count does not match the package set.' }
    $recordNames = @($records | ForEach-Object { $_.file } | Sort-Object)
    $packageNames = @($packages | ForEach-Object { $_.Name } | Sort-Object)
    if ((Compare-Object -ReferenceObject $recordNames -DifferenceObject $packageNames).Count -ne 0) { throw 'RELEASES package names do not exactly match the package set.' }
    foreach ($record in $records) {
        $package = Join-Path $ReleaseDirectory $record.file
        $item = Get-Item -LiteralPath $package
        if ($item.Length -ne $record.size) { throw "RELEASES size mismatch: $($record.file)" }
        $sha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $package).Hash.ToLowerInvariant()
        if ($sha1 -ne $record.sha1) { throw "RELEASES SHA-1 mismatch: $($record.file)" }
    }
    return $records
}

if ($ValidateReleaseFixtureOnly) {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'OutputPath is required for release-fixture validation.' }
    [void](Test-ReleaseIndex $OutputPath)
    Write-Host '[installer] RELEASES fixture is internally consistent.'
    exit 0
}

foreach ($requiredValue in @($PayloadPath, $PayloadProvenancePath, $OutputPath, $Version, $Commit)) {
    if ([string]::IsNullOrWhiteSpace($requiredValue)) { throw 'PayloadPath, PayloadProvenancePath, OutputPath, Version, and Commit are required.' }
}
if ($Commit -notmatch '^[0-9a-f]{40}$') { throw "Invalid packaging commit: $Commit" }
if ($Version -notmatch '^[0-9]+(?:\.[0-9]+){2,3}(?:-[0-9A-Za-z.-]+)?$') { throw "Invalid package version: $Version" }
if ($manifest.signing.allowed -ne $false -or $contract.signing.allowed -ne $false) { throw 'Code signing is prohibited by both delivery contracts.' }
$expectedPayloadPath = Join-Path $repoRoot "build\windows\$Commit\OUTPUT"
$expectedPayloadProvenance = Join-Path $repoRoot "build\windows\$Commit\payload-provenance.json"
$expectedOutputPath = Join-Path $repoRoot "build\release\$Commit\$Version"
Assert-ExactOwnedPath $PayloadPath $expectedPayloadPath 'PayloadPath'
Assert-ExactOwnedPath $PayloadProvenancePath $expectedPayloadProvenance 'PayloadProvenancePath'
Assert-ExactOwnedPath $OutputPath $expectedOutputPath 'OutputPath'
if (-not (Test-Path -LiteralPath $PayloadPath -PathType Container)) { throw "Payload directory is missing: $PayloadPath" }
$payloadProvenance = Assert-PayloadProvenance $PayloadPath $PayloadProvenancePath $Commit

$nuget = Get-Command nuget.exe -ErrorAction SilentlyContinue
if (-not $nuget) { throw 'nuget.exe is unavailable after dependency bootstrap.' }
$packageRoot = Join-Path $repoRoot '.tools\squirrel'
$squirrelPackage = [string]$manifest.nuget.package
$squirrelVersion = [string]$manifest.nuget.version
$squirrelExe = Join-Path $packageRoot "$squirrelPackage.$squirrelVersion\tools\Squirrel.exe"
if (-not (Test-Path -LiteralPath $squirrelExe)) {
    & $nuget.Source install $squirrelPackage -Version $squirrelVersion -Source $manifest.nuget.source -OutputDirectory $packageRoot -NonInteractive -DirectDownload | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "NuGet could not obtain Squirrel.Windows (exit $LASTEXITCODE)." }
}
if (-not (Test-Path -LiteralPath $squirrelExe)) { throw "Squirrel.exe is missing: $squirrelExe" }

$stageBase = Join-Path $repoRoot 'build\squirrel-stage'
$stage = Join-Path $stageBase "$Commit\$Version"
if (Test-Path -LiteralPath $stage) {
    if ((Get-Item -LiteralPath $stage -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clear a reparse-point package staging directory.' }
    Remove-Item -LiteralPath $stage -Recurse -Force
}
if (Test-Path -LiteralPath $OutputPath) {
    if ((Get-Item -LiteralPath $OutputPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clear a reparse-point release directory.' }
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'payload'), $OutputPath | Out-Null
Copy-Item -Path (Join-Path $PayloadPath '*') -Destination (Join-Path $stage 'payload') -Recurse -Force

$template = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'cmake\material-phone\MaterialPhone.nuspec.in')
$nuspec = $template.Replace('@PACKAGE_ID@', [string]$contract.packageId).Replace('@PACKAGE_VERSION@', $Version)
$nuspecPath = Join-Path $stage 'MaterialPhone.nuspec'
Set-Content -LiteralPath $nuspecPath -Value $nuspec -Encoding utf8
& $nuget.Source pack $nuspecPath -OutputDirectory $stage -NoPackageAnalysis -NonInteractive | Out-Host
if ($LASTEXITCODE -ne 0) { throw "NuGet payload packaging failed (exit $LASTEXITCODE)." }
$basePackages = @(Get-ChildItem -LiteralPath $stage -Filter '*.nupkg' -File)
if ($basePackages.Count -ne 1) { throw "Expected exactly one base package, found $($basePackages.Count)." }
& $squirrelExe --releasify $basePackages[0].FullName --releaseDir $OutputPath --no-msi | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Squirrel releasify failed (exit $LASTEXITCODE)." }

$setup = Join-Path $OutputPath 'Setup.exe'
$releases = Join-Path $OutputPath 'RELEASES'
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw 'Squirrel did not produce Setup.exe.' }
$fullPackages = @(Get-ChildItem -LiteralPath $OutputPath -Filter '*-full.nupkg' -File)
if ($fullPackages.Count -eq 0) { throw 'Squirrel did not produce a full .nupkg.' }
$releaseRecords = @(Test-ReleaseIndex $OutputPath)
Assert-UnsignedExecutable $setup

Add-Type -AssemblyName System.IO.Compression.FileSystem
$packageVerifyRoot = Join-Path $stage 'package-verification'
foreach ($package in @(Get-ChildItem -LiteralPath $OutputPath -Filter '*.nupkg' -File)) {
    $extractRoot = Join-Path $packageVerifyRoot $package.BaseName
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    [IO.Compression.ZipFile]::ExtractToDirectory($package.FullName, $extractRoot)
    foreach ($executable in @(Get-ChildItem -LiteralPath $extractRoot -Filter '*.exe' -File -Recurse)) { Assert-UnsignedExecutable $executable.FullName }
}

$payloadProvenanceCopy = Join-Path $OutputPath 'payload-provenance.json'
Copy-Item -LiteralPath $PayloadProvenancePath -Destination $payloadProvenanceCopy -Force
$artifactFiles = @((Get-Item -LiteralPath $setup), (Get-Item -LiteralPath $releases), (Get-Item -LiteralPath $payloadProvenanceCopy)) + @(Get-ChildItem -LiteralPath $OutputPath -Filter '*.nupkg' -File)
$artifacts = @($artifactFiles | Sort-Object Name | ForEach-Object {
    [ordered]@{ name = $_.Name; size = $_.Length; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant() }
})
$provenance = [ordered]@{
    schemaVersion = 2
    commit = $Commit
    version = $Version
    unsigned = $true
    payloadProvenanceSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $PayloadProvenancePath).Hash.ToLowerInvariant()
    applicationExecutable = [string]$contract.applicationExecutableRelativePath
    payloadFileCount = @($payloadProvenance.files).Count
    payloadFiles = @($payloadProvenance.files)
    artifacts = $artifacts
    releaseRecords = @($releaseRecords | ForEach-Object { [ordered]@{ sha1 = $_.sha1; file = $_.file; size = $_.size } })
}
$provenance | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $OutputPath 'build-provenance.json') -Encoding utf8
Write-Host "[installer] Byte-bound unsigned Squirrel contract verified for commit $Commit."
