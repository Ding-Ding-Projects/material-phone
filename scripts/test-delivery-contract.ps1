[CmdletBinding()]
param(
    [string]$Root,
    [switch]$SkipNegativeProofs,
    [switch]$SkipGitlinkProof
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-DeliveryContract([string]$ContractRoot, [bool]$CheckGitlink) {
    $gitmodulesPath = Join-Path $ContractRoot '.gitmodules'
    $manifestPath = Join-Path $ContractRoot 'dependencies.manifest.json'
    $workflowPath = Join-Path $ContractRoot '.github\workflows\windows-delivery.yml'
    $cmakePath = Join-Path $ContractRoot 'CMakeLists.txt'
    $packagePath = Join-Path $ContractRoot 'scripts\package-squirrel.ps1'
    $contractPath = Join-Path $ContractRoot 'cmake\material-phone\squirrel-contract.json'
    foreach ($required in @($gitmodulesPath, $manifestPath, $workflowPath, $cmakePath, $packagePath, $contractPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required delivery file is missing: $required" }
    }

    $gitmodules = Get-Content -Raw -LiteralPath $gitmodulesPath
    if ($gitmodules -match '(?m)^\s*path\s*=\s*external/feature-specs\s*$') {
        throw 'The private external/feature-specs gitlink is registered as a submodule.'
    }
    $cmake = Get-Content -Raw -LiteralPath $cmakePath
    Assert-Contains $cmake 'external/feature-specs is private and must not be registered in the public build' 'The CMake private-input guard is missing.'

    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $manifest.platform -ne 'windows-x64') { throw 'The dependency manifest schema/platform contract is invalid.' }
    if ($manifest.signing.allowed -ne $false) { throw 'The dependency manifest permits code signing.' }
    if (@($manifest.excludedGitlinks) -notcontains 'external/feature-specs') { throw 'The private gitlink is absent from excludedGitlinks.' }
    if (@($manifest.submodules) -contains 'external/feature-specs') { throw 'The private gitlink is present in the public submodule list.' }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.nuget.version)) { throw 'The Squirrel.Windows package version is not pinned.' }
    foreach ($tool in $manifest.winget) {
        if ([string]$tool.sha256 -notmatch '^[0-9a-f]{64}$') { throw "Pinned SHA-256 is missing or invalid for $($tool.id)." }
    }

    $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
    if ($contract.signing.allowed -ne $false -or $contract.signing.requiredAuthenticodeStatus -ne 'NotSigned') {
        throw 'The Squirrel contract does not fail closed on unsigned output.'
    }
    foreach ($artifact in @('Setup.exe', 'RELEASES', '*-full.nupkg')) {
        if (@($contract.requiredArtifacts) -notcontains $artifact) { throw "Required Squirrel artifact is missing from the contract: $artifact" }
    }

    $packageScript = Get-Content -Raw -LiteralPath $packagePath
    foreach ($needle in @('Get-AuthenticodeSignature', '--releasify', '--no-msi', '*-delta.nupkg', 'build-provenance.json')) {
        Assert-Contains $packageScript $needle "Squirrel packaging proof is missing: $needle"
    }

    foreach ($entry in @('build.bat', 'build-installer.bat', 'download-dependencies.bat')) {
        $batch = Get-Content -Raw -LiteralPath (Join-Path $ContractRoot $entry)
        foreach ($needle in @('/s', '--silent', 'SILENT')) {
            Assert-Contains $batch $needle "$entry does not implement $needle."
        }
    }

    $workflow = Get-Content -Raw -LiteralPath $workflowPath
    Assert-Contains $workflow 'workflow_dispatch:' 'The delivery workflow lacks workflow_dispatch.'
    Assert-Contains $workflow 'push:' 'The delivery workflow lacks push.'
    Assert-Contains $workflow 'windows-2022' 'The delivery workflow is not pinned to the Windows 2022 hosted image.'
    Assert-Contains $workflow 'build-installer.bat /s' 'The workflow does not use the supported installer entry point.'
    Assert-Contains $workflow 'if: ${{ always() }}' 'Failure-path artifact collection is missing.'
    Assert-Contains $workflow 'dev-${{ github.run_id }}-${{ github.run_attempt }}' 'The release tag is not unique per run attempt.'
    if ($workflow -match '(?im)^\s*-\s+name:\s+.*\b(test|lint|type.?check|static.?analysis|coverage)\b') {
        throw 'The delivery workflow contains a prohibited test or lint step.'
    }
    if ($workflow -match '(?im)^\s*(npm|pnpm|yarn|ctest|pytest|vitest|eslint|actionlint)\b') {
        throw 'The delivery workflow invokes a prohibited test or lint command.'
    }

    if ($CheckGitlink) {
        $gitlink = (& git -C $ContractRoot ls-files -s -- external/feature-specs).Trim()
        if ($gitlink -notmatch '^160000 [0-9a-f]{40} 0\s+external/feature-specs$') {
            throw 'The historical external/feature-specs gitlink was removed or modified.'
        }
    }
}

Assert-DeliveryContract $Root (-not $SkipGitlinkProof)
Write-Host '[contract] Positive delivery contract passed.'

if (-not $SkipNegativeProofs) {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("material-phone-contract-{0}" -f [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        foreach ($relative in @(
            '.gitmodules', 'dependencies.manifest.json', 'CMakeLists.txt',
            'build.bat', 'build-installer.bat', 'download-dependencies.bat',
            '.github\workflows\windows-delivery.yml',
            'scripts\package-squirrel.ps1',
            'cmake\material-phone\squirrel-contract.json'
        )) {
            $destination = Join-Path $tempRoot $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath (Join-Path $Root $relative) -Destination $destination
        }

        $originalManifest = Get-Content -Raw -LiteralPath (Join-Path $tempRoot 'dependencies.manifest.json')
        $brokenManifest = $originalManifest.Replace('"allowed": false', '"allowed": true')
        if ($brokenManifest -eq $originalManifest) { throw 'Negative proof could not alter the signing policy.' }
        Set-Content -LiteralPath (Join-Path $tempRoot 'dependencies.manifest.json') -Value $brokenManifest -Encoding utf8
        $rejected = $false
        try { Assert-DeliveryContract $tempRoot $false } catch { $rejected = $true }
        if (-not $rejected) { throw 'Negative proof failed: signing-policy removal stayed green.' }
        Set-Content -LiteralPath (Join-Path $tempRoot 'dependencies.manifest.json') -Value $originalManifest -Encoding utf8

        Add-Content -LiteralPath (Join-Path $tempRoot '.gitmodules') -Value "`n[submodule `"feature-specs`"]`n`tpath = external/feature-specs`n`turl = ssh://example.invalid/private.git"
        $rejected = $false
        try { Assert-DeliveryContract $tempRoot $false } catch { $rejected = $true }
        if (-not $rejected) { throw 'Negative proof failed: private submodule registration stayed green.' }
        Write-Host '[contract] Negative proofs turned red for signing and private-input regressions.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}
