[CmdletBinding()]
param(
    [switch]$Silent,
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Configuration = 'RelWithDebInfo'
)

$ErrorActionPreference = 'Stop'
$startedAt = Get-Date
$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Phase([string]$Message) { Write-Host "[build] $Message" }

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Silent) {
    Write-Phase 'Requesting elevation before any installation or build work begins.'
    $child = Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
        '-Configuration', $Configuration
    )
    exit $child.ExitCode
}
if (-not $isAdmin -and $Silent) {
    Write-Phase 'Silent mode is not elevated; continuing with user-scoped tool locations and refusing interactive prompts.'
}

Write-Phase 'Bootstrapping the declared toolchain and public submodules.'
& (Join-Path $repoRoot 'download-dependencies.bat') /s
if ($LASTEXITCODE -ne 0) { throw "Dependency bootstrap failed (exit $LASTEXITCODE)." }

$manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'dependencies.manifest.json') | ConvertFrom-Json
if ($manifest.signing.allowed -ne $false) { throw 'Code signing is prohibited for this build.' }
$qtDir = Join-Path $repoRoot ".tools\Qt\$($manifest.qt.version)\$($manifest.qt.installDirectory)\lib\cmake\Qt6"
if (-not (Test-Path -LiteralPath (Join-Path $qtDir 'Qt6Config.cmake'))) {
    throw "Qt6_DIR is incomplete: $qtDir"
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($commit -notmatch '^[0-9a-f]{40}$') { throw "Invalid source commit identity: $commit" }
$buildBase = Join-Path $repoRoot 'build\windows'
$buildRoot = Join-Path $buildBase $commit
$outputRoot = Join-Path $buildRoot 'OUTPUT'
if (Test-Path -LiteralPath $buildRoot) {
    if ((Get-Item -LiteralPath $buildRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to clear a reparse-point build staging directory.' }
    $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot)
    $resolvedBuildBase = [IO.Path]::GetFullPath($buildBase).TrimEnd('\') + '\'
    if (-not $resolvedBuildRoot.StartsWith($resolvedBuildBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing to clear a build directory outside the owned staging root.' }
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$parallel = [Math]::Max(1, [Math]::Min([Environment]::ProcessorCount, 16))

$configureArguments = @(
    '-S', $repoRoot, '-B', $buildRoot,
    '-G', 'Visual Studio 17 2022', '-A', 'x64',
    "-DQt6_DIR=$qtDir",
    "-DCMAKE_INSTALL_PREFIX=$outputRoot",
    "-DLINPHONEAPP_APPLICATION_NAME=$($manifest.application.displayName)",
    "-DLINPHONEAPP_EXECUTABLE_NAME=$($manifest.application.executableName)",
    '-DENABLE_APP_PACKAGING=OFF',
    '-DENABLE_TESTS=OFF', '-DENABLE_UNIT_TESTS=OFF',
    '-DENABLE_STRICT=OFF', '-DENABLE_WINDOWS_TOOLS_CHECK=ON',
    '-DLINPHONE_WINDOWS_SIGN_TOOL=',
    '-DLINPHONE_BUILDER_SIGNING_IDENTITY='
)
Write-Phase "Configuring $Configuration for x64 with unsigned packaging inputs disabled."
& cmake @configureArguments | Out-Host
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed (exit $LASTEXITCODE)." }

Write-Phase "Building and installing with $parallel parallel workers."
& cmake --build $buildRoot --config $Configuration --target install --parallel $parallel | Out-Host
if ($LASTEXITCODE -ne 0) { throw "CMake build failed (exit $LASTEXITCODE)." }

$expectedExecutable = Join-Path $outputRoot ([string]$manifest.application.executableRelativePath).Replace('/', '\')
if (-not (Test-Path -LiteralPath $expectedExecutable -PathType Leaf)) {
    throw "Build completed without the exact Material Phone executable: $expectedExecutable"
}
$executables = @(Get-ChildItem -LiteralPath $outputRoot -Filter '*.exe' -File -Recurse -ErrorAction SilentlyContinue)
foreach ($executable in $executables) {
    $signature = Get-AuthenticodeSignature -LiteralPath $executable.FullName
    if ([string]$signature.Status -ne 'NotSigned') { throw "Executable must remain unsigned: $($executable.FullName) ($($signature.Status))." }
}
$payloadFiles = @(Get-ChildItem -LiteralPath $outputRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $relative = $_.FullName.Substring($outputRoot.TrimEnd('\').Length + 1).Replace('\', '/')
    [ordered]@{
        path = $relative
        size = $_.Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
})
if ($payloadFiles.Count -eq 0) { throw 'The installed payload is empty.' }
$payloadProvenance = [ordered]@{
    schemaVersion = 1
    commit = $commit
    applicationExecutable = ([string]$manifest.application.executableRelativePath).Replace('\', '/')
    files = $payloadFiles
}
$payloadProvenance | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $buildRoot 'payload-provenance.json') -Encoding utf8
Set-Content -LiteralPath (Join-Path $buildRoot 'build-commit.txt') -Value $commit -Encoding ascii

$elapsed = (Get-Date) - $startedAt
Write-Phase ("Built commit {0} in {1:hh\:mm\:ss}. Runnable output: {2}" -f $commit, $elapsed, $outputRoot)
if (-not $Silent) {
    $answer = Read-Host 'Run the built application now? [y/N]'
    if ($answer -match '^(y|yes)$') {
        Start-Process -FilePath $executables[0].FullName -WorkingDirectory $executables[0].DirectoryName
    }
}
