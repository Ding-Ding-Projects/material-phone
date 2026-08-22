[CmdletBinding()]
param(
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$startedAt = Get-Date
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'dependencies.manifest.json'

function Write-Phase([string]$Message) {
    Write-Host "[dependencies] $Message"
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $Silent) {
    Write-Phase 'Requesting elevation before any installation work begins.'
    $child = Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    )
    exit $child.ExitCode
}
if (-not $isAdmin -and $Silent) {
    Write-Phase 'Silent mode is not elevated; continuing with user-scoped locations and refusing interactive prompts.'
}

function Resolve-Tool([string]$Command) {
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue
    if ($resolved) { return $resolved.Source }
    switch ($Command) {
        'vswhere' {
            $candidates = @(
                (Join-Path $env:LOCALAPPDATA 'MaterialPhoneToolchain\VS2022\Installer\vswhere.exe'),
                (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe')
            )
        }
        'pacman' { $candidates = @('C:\msys64\usr\bin\pacman.exe') }
        default { $candidates = @() }
    }
    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Dependency manifest is missing: $manifestPath"
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.platform -ne 'windows-x64') {
    throw 'Unsupported dependency manifest schema or platform.'
}
if ($manifest.signing.allowed -ne $false) {
    throw 'Dependency manifest violates the permanent code-signing prohibition.'
}

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
    throw 'winget.exe is unavailable. A current Windows App Installer is required to bootstrap the pinned toolchain without manual downloads.'
}

foreach ($tool in $manifest.winget) {
    $catalog = & $winget.Source show --exact --id ([string]$tool.id) --version ([string]$tool.version) --source winget --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Pinned winget package is unavailable: $($tool.id) $($tool.version)." }
    $catalogHashLine = $catalog | Select-String -Pattern '^\s*Installer SHA256:\s*([0-9a-fA-F]{64})\s*$' | Select-Object -First 1
    if (-not $catalogHashLine -or $catalogHashLine.Matches[0].Groups[1].Value.ToLowerInvariant() -ne ([string]$tool.sha256).ToLowerInvariant()) {
        throw "winget catalog digest does not match dependencies.manifest.json for $($tool.id) $($tool.version)."
    }
    $existing = Resolve-Tool $tool.command
    & $winget.Source list --exact --id ([string]$tool.id) --version ([string]$tool.version) --source winget --accept-source-agreements --disable-interactivity *> $null
    $exactVersionInstalled = $LASTEXITCODE -eq 0
    if ($existing -and $exactVersionInstalled) {
        Write-Phase "Found exact $($tool.id) $($tool.version) at $existing; reusing it."
        continue
    }
    Write-Phase "Installing $($tool.id) $($tool.version) from the canonical winget source."
    $arguments = @(
        'install', '--exact', '--id', [string]$tool.id,
        '--version', [string]$tool.version,
        '--source', 'winget', '--accept-package-agreements',
        '--accept-source-agreements', '--disable-interactivity', '--force'
    )
    if ($tool.override) {
        $arguments += @('--override', [Environment]::ExpandEnvironmentVariables([string]$tool.override))
    }
    & $winget.Source @arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "winget could not install $($tool.id) $($tool.version) (exit $LASTEXITCODE)."
    }
}

# Refresh only this process. Package-manager changes normally affect future shells.
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath;$env:Path;C:\msys64\usr\bin;C:\msys64\mingw64\bin"

$python = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $python) { throw 'Python 3.11 was installed but py.exe is still unavailable after PATH refresh.' }
$toolRoot = Join-Path $repoRoot $manifest.toolRoot
$venv = Join-Path $toolRoot 'python'
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Phase "Creating the project-local Python tool environment at $venv."
    & $python.Source -3.11 -m venv $venv | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Python could not create the project-local tool environment.' }
}
foreach ($package in $manifest.python.packages) {
    Write-Phase "Ensuring Python package $package is installed."
    & $venvPython -m pip install --disable-pip-version-check --no-input $package | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Python package installation failed: $package" }
}

$qtRoot = Join-Path $toolRoot 'Qt'
$qtVersion = [string]$manifest.qt.version
$qtArch = [string]$manifest.qt.architecture
$qtConfig = Join-Path $qtRoot "$qtVersion\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake"
if (-not (Test-Path -LiteralPath $qtConfig)) {
    Write-Phase "Installing Qt $qtVersion ($qtArch) and declared modules into $qtRoot."
    $qtArguments = @(
        '-m', 'aqt', 'install-qt', [string]$manifest.qt.host,
        [string]$manifest.qt.target, $qtVersion, $qtArch,
        '-O', $qtRoot, '--modules'
    ) + @($manifest.qt.modules)
    & $venvPython @qtArguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Qt $qtVersion installation failed." }
}
if (-not (Test-Path -LiteralPath $qtConfig)) {
    throw "Qt installation completed without the expected configuration file: $qtConfig"
}

$pacman = Resolve-Tool 'pacman'
if (-not $pacman) { throw 'MSYS2 was installed but pacman.exe is unavailable at C:\msys64\usr\bin.' }
Write-Phase 'Refreshing the MSYS2 package database and installing the pinned manifest package set.'
& $pacman -Syu --noconfirm | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 database refresh failed (exit $LASTEXITCODE)." }
& $pacman -S --needed --noconfirm @($manifest.msys2.packages) | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 package installation failed (exit $LASTEXITCODE)." }

Write-Phase 'Initializing only public, manifest-listed submodules.'
& git -C $repoRoot submodule sync -- @($manifest.submodules) | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Public submodule synchronization failed.' }
& git -C $repoRoot submodule update --init --recursive --jobs 4 -- @($manifest.submodules) | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Public submodule initialization failed.' }

foreach ($excluded in $manifest.excludedGitlinks) {
    $registered = & git -C $repoRoot config --file .gitmodules --get-regexp '^submodule\..*\.path$' 2>$null |
        Select-String -SimpleMatch ([string]$excluded)
    if ($registered) { throw "Excluded private gitlink is registered as a submodule: $excluded" }
}

$elapsed = (Get-Date) - $startedAt
Write-Phase ("Complete in {0:hh\:mm\:ss}. Tool root: {1}" -f $elapsed, $toolRoot)
