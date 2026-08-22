[CmdletBinding()]
param(
    [string]$Root,
    [switch]$SkipNegativeProofs,
    [switch]$SkipGitlinkProof
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent $PSScriptRoot }

function Assert-ExactLine([string]$Text, [string]$Pattern, [string]$Message) {
    if (-not [regex]::IsMatch($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)) { throw $Message }
}

function Get-FunctionNames([string]$ScriptPath) {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw "PowerShell parse failure in ${ScriptPath}: $($errors[0].Message)" }
    return @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
}

function Get-GitmoduleEntries([string]$Path) {
    $entries = New-Object System.Collections.Generic.List[object]
    $current = $null
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*\[submodule\s+"([^"]+)"\]\s*$') {
            if ($current) { $entries.Add([pscustomobject]$current) }
            $current = [ordered]@{ name = $Matches[1]; path = $null; url = $null }
            continue
        }
        if (-not $current) { continue }
        if ($line -match '^\s*path\s*=\s*(\S+)\s*$') { $current.path = $Matches[1] }
        elseif ($line -match '^\s*url\s*=\s*(\S+)\s*$') { $current.url = $Matches[1] }
    }
    if ($current) { $entries.Add([pscustomobject]$current) }
    return $entries.ToArray()
}

function Assert-DeliveryContract([string]$ContractRoot, [bool]$CheckGitlink) {
    $paths = [ordered]@{
        gitmodules = Join-Path $ContractRoot '.gitmodules'
        manifest = Join-Path $ContractRoot 'dependencies.manifest.json'
        workflow = Join-Path $ContractRoot '.github\workflows\windows-delivery.yml'
        cmake = Join-Path $ContractRoot 'CMakeLists.txt'
        package = Join-Path $ContractRoot 'scripts\package-squirrel.ps1'
        download = Join-Path $ContractRoot 'scripts\download-dependencies.ps1'
        build = Join-Path $ContractRoot 'scripts\build-windows.ps1'
        installer = Join-Path $ContractRoot 'scripts\build-installer-windows.ps1'
        contract = Join-Path $ContractRoot 'cmake\material-phone\squirrel-contract.json'
    }
    foreach ($path in $paths.Values) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required delivery file is missing: $path" } }

    $gitmodules = Get-Content -Raw -LiteralPath $paths.gitmodules
    if ($gitmodules -match '(?m)^\s*path\s*=\s*external/feature-specs\s*$') {
        throw 'The private external/feature-specs gitlink is registered as a submodule.'
    }
    $cmake = Get-Content -Raw -LiteralPath $paths.cmake
    Assert-ExactLine $cmake '^\s*message\(FATAL_ERROR "external/feature-specs is private and must not be registered in the public build"\)$' 'The CMake private-input guard is missing.'
    Assert-ExactLine $cmake '^\s*message\(FATAL_ERROR "external/feature-specs is private and must not exist in the public build"\)$' 'The CMake private-path guard is missing.'
    Assert-ExactLine $cmake '^\s*add_subdirectory\("Linphone/pbx"\)$' 'The PBX provider is not registered in the production build graph.'

    $manifest = Get-Content -Raw -LiteralPath $paths.manifest | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1 -or $manifest.platform -ne 'windows-x64') { throw 'The dependency manifest schema/platform contract is invalid.' }
    if ($manifest.signing.allowed -ne $false) { throw 'The dependency manifest permits code signing.' }
    if ([string]$manifest.application.executableRelativePath -ne 'bin/MaterialPhone.exe') { throw 'The manifest does not require the exact Material Phone executable path.' }
    $registeredModules = @(Get-GitmoduleEntries $paths.gitmodules)
    if ($registeredModules.Count -ne @($manifest.submodules).Count) { throw '.gitmodules entry count differs from the exact public allowlist.' }
    foreach ($expected in @($manifest.submodules)) {
        $matches = @($registeredModules | Where-Object { $_.name -eq [string]$expected.name -and $_.path -eq [string]$expected.path -and $_.url -eq [string]$expected.url })
        if ($matches.Count -ne 1) { throw "The .gitmodules entry is not exactly allowlisted: $($expected.name)." }
    }
    foreach ($excluded in @($manifest.excludedGitlinks)) { if (@($registeredModules.path) -contains [string]$excluded) { throw "Excluded gitlink is registered: $excluded" } }
    foreach ($tool in $manifest.winget) { if ([string]$tool.sha256 -notmatch '^[0-9a-f]{64}$') { throw "Pinned SHA-256 is invalid for $($tool.id)." } }
    $proofNames = @($manifest.qt.moduleProofs.PSObject.Properties.Name | Sort-Object)
    $moduleNames = @($manifest.qt.modules | Sort-Object)
    if ((Compare-Object -ReferenceObject $moduleNames -DifferenceObject $proofNames).Count -ne 0) { throw 'Qt module proofs do not exactly cover the declared module set.' }

    $contract = Get-Content -Raw -LiteralPath $paths.contract | ConvertFrom-Json
    if ($contract.signing.allowed -ne $false -or $contract.signing.requiredAuthenticodeStatus -ne 'NotSigned') { throw 'The Squirrel contract does not fail closed on unsigned output.' }
    if (-not [bool]$contract.signing.verifyPayloadExecutables -or -not [bool]$contract.signing.verifyPackageExecutables) { throw 'Executable signing coverage is incomplete.' }
    if ([string]$contract.applicationExecutableRelativePath -ne [string]$manifest.application.executableRelativePath) { throw 'Manifest and packaging executable identities differ.' }
    foreach ($artifact in @('Setup.exe', 'RELEASES', '*-full.nupkg', 'payload-provenance.json')) { if (@($contract.requiredArtifacts) -notcontains $artifact) { throw "Required artifact missing from contract: $artifact" } }

    $packageFunctions = @(Get-FunctionNames $paths.package)
    foreach ($functionName in @('Assert-UnsignedExecutable', 'Assert-ExactOwnedPath', 'Assert-PayloadProvenance', 'Get-ReleaseRecords', 'Test-ReleaseIndex')) {
        if ($packageFunctions -notcontains $functionName) { throw "Required parsed packaging function is missing: $functionName" }
    }
    $packageText = Get-Content -Raw -LiteralPath $paths.package
    Assert-ExactLine $packageText '^\s*if \(\$line -notmatch ''\^\(\[0-9A-Fa-f\]\{40\}\)' 'RELEASES records are not parsed through the anchored hash/name/size grammar.'
    Assert-ExactLine $packageText '^\s*foreach \(\$executable in @\(Get-ChildItem -LiteralPath \$Root -Filter ''\*\.exe'' -File -Recurse\)\)' 'Payload executable signing coverage is missing.'
    Assert-ExactLine $packageText '^\s*foreach \(\$executable in @\(Get-ChildItem -LiteralPath \$extractRoot -Filter ''\*\.exe'' -File -Recurse\)\)' 'Packaged executable signing coverage is missing.'

    $downloadText = Get-Content -Raw -LiteralPath $paths.download
    if ($downloadText -match '(?m)^\s*& git .*submodule update .*--recursive') { throw 'Unbounded recursive submodule expansion is present.' }
    Assert-ExactLine $downloadText '^\$registeredModules = @\(Get-GitmoduleEntries \$gitmodulesPath\)$' 'Submodule allowlist validation is missing.'
    $allowlistBoundary = [regex]::Match($downloadText, '(?m)^\$registeredModules = @\(Get-GitmoduleEntries \$gitmodulesPath\)$')
    $networkBoundary = [regex]::Match($downloadText, '(?m)^\$winget = Get-Command winget\.exe ')
    if (-not $allowlistBoundary.Success -or -not $networkBoundary.Success -or $allowlistBoundary.Index -ge $networkBoundary.Index) { throw 'Submodule allowlist validation does not precede the first network bootstrap boundary.' }
    Assert-ExactLine $downloadText '^\$missingQt = @\(Get-MissingQtProofs \$manifest \$qtInstallRoot\)' 'Qt cache completeness is not derived from every module proof.'

    $buildText = Get-Content -Raw -LiteralPath $paths.build
    Assert-ExactLine $buildText '^\$buildRoot = Join-Path \$buildBase \$commit$' 'Build staging is not commit-specific.'
    Assert-ExactLine $buildText '^\$expectedExecutable = Join-Path \$outputRoot ' 'The exact Material Phone executable is not required.'
    Assert-ExactLine $buildText '^\$payloadProvenance \| ConvertTo-Json ' 'Payload byte provenance is not emitted.'
    $installerText = Get-Content -Raw -LiteralPath $paths.installer
    Assert-ExactLine $installerText '^\$releaseDir = Join-Path \$repoRoot "build\\release\\\$expectedCommit\\\$Version"$' 'Release staging is not commit/version specific.'
    Assert-ExactLine $installerText '^& \(Join-Path \$PSScriptRoot ''package-squirrel\.ps1''\) -PayloadPath \$payload -PayloadProvenancePath ' 'Installer packaging is not bound to payload provenance.'

    $workflow = Get-Content -Raw -LiteralPath $paths.workflow
    Assert-ExactLine $workflow '^permissions:$' 'Workflow permissions block is missing.'
    Assert-ExactLine $workflow '^  contents: read$' 'The workflow default permission is not contents:read.'
    $buildJob = [regex]::Match($workflow, '(?ms)^  build:\r?$.*?(?=^  publish:\r?$)')
    $publishJob = [regex]::Match($workflow, '(?ms)^  publish:\r?$.*\z')
    if (-not $buildJob.Success -or -not $publishJob.Success) { throw 'Build and publish jobs are not independently bounded.' }
    if ($buildJob.Value -match '\bGH_TOKEN\b' -or $buildJob.Value -match 'contents:\s*write') { throw 'Build/bootstrap/package receives a publication credential or write permission.' }
    if ($publishJob.Value -notmatch '(?m)^      contents: write$' -or $publishJob.Value -notmatch '(?m)^          GH_TOKEN: \$\{\{ secrets\.RELEASE_TOKEN \|\| secrets\.ORG_TOKEN \|\| secrets\.GITHUB_TOKEN \}\}$') { throw 'Publication permission/token is not scoped to the release step.' }
    $expectedActions = @{
        'actions/checkout' = '11d5960a326750d5838078e36cf38b85af677262'
        'actions/upload-artifact' = 'ea165f8d65b6e75b540449e92b4886f43607fa02'
        'actions/download-artifact' = 'd3f86a106a0bac45b974a628896c90dbdf5c8093'
    }
    foreach ($action in $expectedActions.GetEnumerator()) {
        $escapedName = [regex]::Escape($action.Key)
        Assert-ExactLine $workflow "^\s+uses: $escapedName@$($action.Value) # v4$" "Third-party action is not pinned to the reviewed immutable SHA: $($action.Key)"
    }
    if ($workflow -match '(?im)^\s*-\s+name:\s+.*\b(test|lint|type.?check|static.?analysis|coverage)\b' -or $workflow -match '(?im)^\s*(npm|pnpm|yarn|ctest|pytest|vitest|eslint|actionlint)\b') { throw 'The workflow contains a prohibited quality-verdict step.' }

    if ($CheckGitlink) {
        $gitlinkOutput = @(& git -C $ContractRoot ls-files -s -- external/feature-specs)
        $gitlink = ($gitlinkOutput -join "`n").Trim()
        if (-not [string]::IsNullOrWhiteSpace($gitlink)) {
            throw 'The private external/feature-specs gitlink is tracked in the public repository.'
        }
    }
}

Assert-DeliveryContract $Root (-not $SkipGitlinkProof)
Write-Host '[contract] Positive delivery contract passed.'

if (-not $SkipNegativeProofs) {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("material-phone-contract-{0}" -f [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        foreach ($relative in @('.gitmodules','dependencies.manifest.json','CMakeLists.txt','build.bat','build-installer.bat','download-dependencies.bat','.github\workflows\windows-delivery.yml','scripts\package-squirrel.ps1','scripts\download-dependencies.ps1','scripts\build-windows.ps1','scripts\build-installer-windows.ps1','cmake\material-phone\squirrel-contract.json')) {
            $destination = Join-Path $tempRoot $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item -LiteralPath (Join-Path $Root $relative) -Destination $destination
        }

        $mutations = @(
            @{ path='dependencies.manifest.json'; old='"allowed": false'; new='"allowed": true'; label='signing policy' },
            @{ path='.github\workflows\windows-delivery.yml'; old="permissions:`n  contents: read"; new="permissions:`n  contents: write"; label='build token privilege' },
            @{ path='.gitmodules'; old='https://gitlab.linphone.org/BC/public/linphone-sdk.git'; new='https://example.invalid/unreviewed.git'; label='submodule URL allowlist' },
            @{ path='scripts\download-dependencies.ps1'; old='submodule update --init --jobs'; new='submodule update --init --recursive --jobs'; label='recursive submodule expansion' }
        )
        foreach ($mutation in $mutations) {
            $path = Join-Path $tempRoot $mutation.path
            $original = Get-Content -Raw -LiteralPath $path
            $broken = $original.Replace($mutation.old, $mutation.new)
            if ($broken -eq $original) { throw "Negative proof could not alter $($mutation.label)." }
            Set-Content -LiteralPath $path -Value $broken -Encoding utf8
            $rejected = $false
            try { Assert-DeliveryContract $tempRoot $false } catch { $rejected = $true }
            if (-not $rejected) { throw "Negative proof stayed green: $($mutation.label)." }
            Set-Content -LiteralPath $path -Value $original -Encoding utf8
        }

        $qtRoot = Join-Path $tempRoot 'qt-cache'
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $Root 'dependencies.manifest.json') | ConvertFrom-Json
        $installRoot = Join-Path $qtRoot "$($manifest.qt.version)\$($manifest.qt.installDirectory)"
        $allProofs = @('lib/cmake/Qt6/Qt6Config.cmake') + @($manifest.qt.moduleProofs.PSObject.Properties.Value)
        foreach ($proof in $allProofs) { $path = Join-Path $installRoot ([string]$proof).Replace('/', '\'); New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null; Set-Content -LiteralPath $path -Value 'fixture' -Encoding ascii }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\download-dependencies.ps1') -ValidateQtCacheOnly -QtRootOverride $qtRoot
        if ($LASTEXITCODE -ne 0) { throw 'Complete Qt warm-cache fixture was rejected.' }
        Remove-Item -LiteralPath (Join-Path $installRoot ([string]$manifest.qt.moduleProofs.qtmultimedia).Replace('/', '\')) -Force
        $strictPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\download-dependencies.ps1') -ValidateQtCacheOnly -QtRootOverride $qtRoot *> $null
        $negativeExit = $LASTEXITCODE
        $ErrorActionPreference = $strictPreference
        if ($negativeExit -eq 0) { throw 'Missing-module Qt warm cache stayed green.' }

        $releaseFixture = Join-Path $tempRoot 'release-fixture'
        New-Item -ItemType Directory -Force -Path $releaseFixture | Out-Null
        $packagePath = Join-Path $releaseFixture 'MaterialPhone-1.0.0-full.nupkg'
        Set-Content -LiteralPath $packagePath -Value 'fixture-package' -Encoding ascii
        $package = Get-Item -LiteralPath $packagePath
        $sha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $packagePath).Hash.ToLowerInvariant()
        Set-Content -LiteralPath (Join-Path $releaseFixture 'RELEASES') -Value "$sha1 $($package.Name) $($package.Length)" -Encoding ascii
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\package-squirrel.ps1') -ValidateReleaseFixtureOnly -OutputPath $releaseFixture
        if ($LASTEXITCODE -ne 0) { throw 'Valid RELEASES fixture was rejected.' }
        Set-Content -LiteralPath (Join-Path $releaseFixture 'RELEASES') -Value "0000000000000000000000000000000000000000 $($package.Name) $($package.Length)" -Encoding ascii
        $strictPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'scripts\package-squirrel.ps1') -ValidateReleaseFixtureOnly -OutputPath $releaseFixture *> $null
        $negativeExit = $LASTEXITCODE
        $ErrorActionPreference = $strictPreference
        if ($negativeExit -eq 0) { throw 'Corrupt RELEASES hash stayed green.' }
        Write-Host '[contract] Negative proofs turned red for privilege, signing, submodule URL allowlisting, recursive submodules, Qt cache completeness, and RELEASES integrity.'
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}
