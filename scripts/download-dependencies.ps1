[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$ValidateQtCacheOnly,
    [string]$QtRootOverride
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$startedAt = Get-Date
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'dependencies.manifest.json'

function Write-Phase([string]$Message) {
    Write-Host "[dependencies] $Message"
}

function Get-QtInstallRoot($Manifest, [string]$BaseRoot) {
    return Join-Path $BaseRoot "$($Manifest.qt.version)\$($Manifest.qt.installDirectory)"
}

function Get-MissingQtProofs($Manifest, [string]$InstallRoot) {
    $missing = New-Object System.Collections.Generic.List[string]
    $baseProof = Join-Path $InstallRoot 'lib\cmake\Qt6\Qt6Config.cmake'
    if (-not (Test-Path -LiteralPath $baseProof -PathType Leaf)) { $missing.Add('base:Qt6Config.cmake') }
    foreach ($module in @($Manifest.qt.modules)) {
        $proofProperty = $Manifest.qt.moduleProofs.PSObject.Properties[[string]$module]
        if (-not $proofProperty -or [string]::IsNullOrWhiteSpace([string]$proofProperty.Value)) {
            $missing.Add("manifest:$module")
            continue
        }
        $proofPath = Join-Path $InstallRoot ([string]$proofProperty.Value).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $proofPath -PathType Leaf)) { $missing.Add([string]$module) }
    }
    return @($missing)
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

function Get-FallbackInstallRoot($Tool, [string]$BaseRoot) {
    $safeId = ([string]$Tool.id) -replace '[^A-Za-z0-9._-]', '_'
    return Join-Path $BaseRoot "bootstrap\$safeId\$($Tool.version)"
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Resolve-FallbackTool($Tool, [string]$BaseRoot) {
    if (-not $Tool.fallback) { return $null }
    $installRoot = Get-FallbackInstallRoot $Tool $BaseRoot
    $commandPath = Join-Path $installRoot ([string]$Tool.fallback.commandRelativePath).Replace('/', '\')
    if (Test-Path -LiteralPath $commandPath -PathType Leaf) { return $commandPath }
    return $null
}

function Add-ToolPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not (($env:Path -split ';') -contains $resolvedPath)) { $env:Path = "$resolvedPath;$env:Path" }
    if ($env:GITHUB_PATH) { Add-Content -LiteralPath $env:GITHUB_PATH -Value $resolvedPath }
}

function Get-CanonicalDownload($Fallback, [string]$DownloadRoot) {
    $uri = [Uri]([string]$Fallback.url)
    $allowedHosts = @(
        'github.com',
        'release-assets.githubusercontent.com',
        'objects.githubusercontent.com',
        'www.python.org',
        'dist.nuget.org'
    )
    if ($uri.Scheme -ne 'https' -or $allowedHosts -notcontains $uri.Host.ToLowerInvariant()) {
        throw "Portable fallback URL is not an allowlisted canonical HTTPS source: $uri"
    }
    $expectedHash = ([string]$Fallback.sha256).ToLowerInvariant()
    if ($expectedHash -notmatch '^[0-9a-f]{64}$') { throw "Portable fallback SHA-256 is invalid for $uri." }
    $maxBytes = if ($Fallback.maxDownloadBytes) { [long]$Fallback.maxDownloadBytes } else { 1073741824L }
    $timeoutSeconds = if ($Fallback.downloadTimeoutSeconds) { [int]$Fallback.downloadTimeoutSeconds } else { 600 }
    $heartbeatSeconds = if ($Fallback.heartbeatSeconds) { [int]$Fallback.heartbeatSeconds } else { 15 }
    if ($maxBytes -le 0 -or $timeoutSeconds -le 0 -or $heartbeatSeconds -le 0) { throw "Portable fallback bounds are invalid for $uri." }
    New-Item -ItemType Directory -Force -Path $DownloadRoot | Out-Null
    $leaf = [IO.Path]::GetFileName($uri.AbsolutePath)
    if ([string]::IsNullOrWhiteSpace($leaf)) { throw "Portable fallback URL has no artifact filename: $uri" }
    $destination = Join-Path $DownloadRoot "$expectedHash-$leaf"
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $cachedLength = (Get-Item -LiteralPath $destination).Length
        if ($cachedLength -gt $maxBytes) { throw "Cached portable fallback exceeds its $maxBytes-byte bound: $destination ($cachedLength bytes)." }
        Write-Phase "Verifying cached fallback $leaf ($cachedLength bytes)."
        $cachedHash = Get-Sha256 $destination
        if ($cachedHash -eq $expectedHash) { return $destination }
        Remove-Item -LiteralPath $destination -Force
    }
    $temporary = "$destination.partial-$PID"
    $handler = $null
    $client = $null
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $cancellation = $null
    try {
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object -TypeName Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $true
        $handler.MaxAutomaticRedirections = 5
        $client = New-Object -TypeName Net.Http.HttpClient -ArgumentList $handler
        $client.Timeout = [Threading.Timeout]::InfiniteTimeSpan
        $client.DefaultRequestHeaders.UserAgent.ParseAdd('MaterialPhone-Bootstrap/1.0')
        $cancellation = New-Object -TypeName Threading.CancellationTokenSource
        $started = Get-Date
        $lastHeartbeat = $started
        Write-Phase "Downloading $leaf from the canonical upstream (timeout ${timeoutSeconds}s; maximum $maxBytes bytes)."
        $request = $client.GetAsync($uri, [Net.Http.HttpCompletionOption]::ResponseHeadersRead, $cancellation.Token)
        while (-not $request.IsCompleted) {
            $elapsedSeconds = [int]((Get-Date) - $started).TotalSeconds
            if ($elapsedSeconds -ge $timeoutSeconds) {
                $cancellation.Cancel()
                throw "Portable fallback download timed out after ${timeoutSeconds}s while waiting for response headers: $uri"
            }
            if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
                Write-Phase "Download heartbeat for ${leaf}: waiting for response headers (${elapsedSeconds}s elapsed)."
                $lastHeartbeat = Get-Date
            }
            Start-Sleep -Milliseconds 250
        }
        $response = $request.GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) { throw "Portable fallback download returned HTTP $([int]$response.StatusCode) $($response.ReasonPhrase): $uri" }
        $finalUri = $response.RequestMessage.RequestUri
        if ($finalUri.Scheme -ne 'https' -or $allowedHosts -notcontains $finalUri.Host.ToLowerInvariant()) {
            throw "Portable fallback redirected outside the canonical host allowlist: $finalUri"
        }
        $contentLength = $response.Content.Headers.ContentLength
        if ($contentLength -and $contentLength -gt $maxBytes) { throw "Portable fallback declares $contentLength bytes, exceeding its $maxBytes-byte bound: $uri" }
        $inputStream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $outputStream = New-Object -TypeName IO.FileStream -ArgumentList @($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $buffer = New-Object byte[] 1048576
        [long]$downloaded = 0
        while ($true) {
            $readTask = $inputStream.ReadAsync($buffer, 0, $buffer.Length, $cancellation.Token)
            while (-not $readTask.IsCompleted) {
                $elapsedSeconds = [int]((Get-Date) - $started).TotalSeconds
                if ($elapsedSeconds -ge $timeoutSeconds) {
                    $cancellation.Cancel()
                    throw "Portable fallback download timed out after ${timeoutSeconds}s at $downloaded bytes: $uri"
                }
                if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
                    $expectedText = if ($contentLength) { "/ $contentLength" } else { '' }
                    Write-Phase "Download heartbeat for ${leaf}: $downloaded $expectedText bytes (${elapsedSeconds}s elapsed)."
                    $lastHeartbeat = Get-Date
                }
                Start-Sleep -Milliseconds 250
            }
            $read = $readTask.GetAwaiter().GetResult()
            if ($read -eq 0) { break }
            $downloaded += $read
            if ($downloaded -gt $maxBytes) { throw "Portable fallback exceeded its $maxBytes-byte bound while downloading: $uri" }
            $outputStream.Write($buffer, 0, $read)
            if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
                $elapsedSeconds = [int]((Get-Date) - $started).TotalSeconds
                $expectedText = if ($contentLength) { "/ $contentLength" } else { '' }
                Write-Phase "Download heartbeat for ${leaf}: $downloaded $expectedText bytes (${elapsedSeconds}s elapsed)."
                $lastHeartbeat = Get-Date
            }
        }
        $outputStream.Flush()
        $outputStream.Dispose()
        $outputStream = $null
        Write-Phase "Downloaded $leaf ($downloaded bytes); verifying SHA-256."
        $actualHash = Get-Sha256 $temporary
        if ($actualHash -ne $expectedHash) { throw "Portable fallback digest mismatch for $uri. Expected $expectedHash; received $actualHash." }
        Move-Item -LiteralPath $temporary -Destination $destination
    }
    finally {
        if ($outputStream) { $outputStream.Dispose() }
        if ($inputStream) { $inputStream.Dispose() }
        if ($response) { $response.Dispose() }
        if ($client) { $client.Dispose() }
        if ($handler) { $handler.Dispose() }
        if ($cancellation) { $cancellation.Dispose() }
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
    return $destination
}

function Install-FallbackTool($Tool, [string]$BaseRoot) {
    if (-not $Tool.fallback) { return $null }
    $fallback = $Tool.fallback
    $supportedKinds = @('zip', 'tar', 'exe', 'file')
    if ($supportedKinds -notcontains [string]$fallback.kind) { throw "Unsupported portable fallback kind for $($Tool.id): $($fallback.kind)." }
    $installRoot = Get-FallbackInstallRoot $Tool $BaseRoot
    $commandPath = Join-Path $installRoot ([string]$fallback.commandRelativePath).Replace('/', '\')
    $artifact = Get-CanonicalDownload $fallback (Join-Path $BaseRoot 'downloads')
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        if (Test-Path -LiteralPath $installRoot) { Remove-Item -LiteralPath $installRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
        switch ([string]$fallback.kind) {
            'zip' {
                $extractRoot = "$installRoot.extract-$PID"
                try {
                    Expand-Archive -LiteralPath $artifact -DestinationPath $extractRoot -Force
                    $sourceRoot = $extractRoot
                    if ($fallback.stripSingleDirectory) {
                        $children = @(Get-ChildItem -LiteralPath $extractRoot)
                        if ($children.Count -ne 1 -or -not $children[0].PSIsContainer) { throw "Portable fallback archive for $($Tool.id) does not contain one root directory." }
                        $sourceRoot = $children[0].FullName
                    }
                    Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force
                }
                finally {
                    if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
                }
            }
            'tar' {
                $extractTimeoutSeconds = if ($fallback.extractTimeoutSeconds) { [int]$fallback.extractTimeoutSeconds } else { 300 }
                $heartbeatSeconds = if ($fallback.heartbeatSeconds) { [int]$fallback.heartbeatSeconds } else { 15 }
                if ($extractTimeoutSeconds -le 0 -or $heartbeatSeconds -le 0) { throw "Portable fallback extraction bounds are invalid for $($Tool.id)." }
                $windowsTar = Join-Path $env:WINDIR 'System32\tar.exe'
                if (-not (Test-Path -LiteralPath $windowsTar -PathType Leaf)) { throw "Bounded archive extraction requires Windows tar.exe at $windowsTar." }
                $extractParent = Split-Path -Parent $installRoot
                if ($env:RUNNER_TEMP) {
                    $runnerTemp = [IO.Path]::GetFullPath([string]$env:RUNNER_TEMP)
                    $installVolume = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($installRoot))
                    $runnerTempVolume = [IO.Path]::GetPathRoot($runnerTemp)
                    if ((Test-Path -LiteralPath $runnerTemp -PathType Container) -and $runnerTempVolume.Equals($installVolume, [StringComparison]::OrdinalIgnoreCase)) {
                        $extractParent = $runnerTemp
                        Write-Phase "Using same-volume runner temporary storage for $($Tool.id) extraction: $extractParent"
                    }
                    else {
                        Write-Phase "Runner temporary storage is unavailable or cross-volume; extracting $($Tool.id) beside its final tool root."
                    }
                }
                $safeId = ([string]$Tool.id) -replace '[^A-Za-z0-9._-]', '_'
                $extractRoot = Join-Path $extractParent "$safeId-$($Tool.version)-extract-$PID"
                if (Test-Path -LiteralPath $extractRoot) { throw "Portable fallback extraction directory already exists: $extractRoot" }
                $process = $null
                try {
                    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
                    Write-Phase "Extracting $([IO.Path]::GetFileName($artifact)) with $windowsTar (timeout ${extractTimeoutSeconds}s)."
                    $process = Start-Process -FilePath $windowsTar -WindowStyle Hidden -PassThru -ArgumentList @(
                        '-xf', ('"{0}"' -f $artifact), '-C', ('"{0}"' -f $extractRoot)
                    )
                    $extractStarted = Get-Date
                    $lastExtractHeartbeat = $extractStarted
                    while (-not $process.HasExited) {
                        $elapsedSeconds = [int]((Get-Date) - $extractStarted).TotalSeconds
                        if ($elapsedSeconds -ge $extractTimeoutSeconds) {
                            $process.Kill()
                            $process.WaitForExit()
                            throw "Portable fallback extraction timed out after ${extractTimeoutSeconds}s for $($Tool.id): $artifact"
                        }
                        if (((Get-Date) - $lastExtractHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
                            Write-Phase "Extraction heartbeat for $($Tool.id): ${elapsedSeconds}s elapsed."
                            $lastExtractHeartbeat = Get-Date
                        }
                        Start-Sleep -Milliseconds 250
                    }
                    if ($process.ExitCode -ne 0) { throw "Portable fallback extraction failed for $($Tool.id) (exit $($process.ExitCode))." }
                    Write-Phase "Archive extraction completed for $($Tool.id) in $([int]((Get-Date) - $extractStarted).TotalSeconds)s; validating its root."
                    $sourceRoot = $extractRoot
                    if ($fallback.stripSingleDirectory) {
                        $children = @(Get-ChildItem -LiteralPath $extractRoot)
                        if ($children.Count -ne 1 -or -not $children[0].PSIsContainer) { throw "Portable fallback archive for $($Tool.id) does not contain one root directory." }
                        $sourceRoot = $children[0].FullName
                    }
                    if ($fallback.stripSingleDirectory) {
                        $stagingTimeoutSeconds = if ($fallback.stagingTimeoutSeconds) { [int]$fallback.stagingTimeoutSeconds } else { 60 }
                        if ($stagingTimeoutSeconds -le 0) { throw "Portable fallback staging timeout is invalid for $($Tool.id)." }
                        Remove-Item -LiteralPath $installRoot -Force
                        Write-Phase "Staging $($Tool.id) by moving its verified single archive root into place (timeout ${stagingTimeoutSeconds}s)."
                        $stagingStarted = Get-Date
                        $lastStagingHeartbeat = $stagingStarted
                        $stagingJob = Start-Job -ScriptBlock {
                            param([string]$Source, [string]$Destination)
                            [IO.Directory]::Move($Source, $Destination)
                        } -ArgumentList $sourceRoot, $installRoot
                        try {
                            while ($stagingJob.State -in @('NotStarted', 'Running')) {
                                $elapsedSeconds = [int]((Get-Date) - $stagingStarted).TotalSeconds
                                if ($elapsedSeconds -ge $stagingTimeoutSeconds) {
                                    Stop-Job -Job $stagingJob
                                    throw "Portable fallback staging timed out after ${stagingTimeoutSeconds}s for $($Tool.id): $installRoot"
                                }
                                if (((Get-Date) - $lastStagingHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
                                    Write-Phase "Staging heartbeat for $($Tool.id): ${elapsedSeconds}s elapsed."
                                    $lastStagingHeartbeat = Get-Date
                                }
                                Start-Sleep -Milliseconds 250
                            }
                            if ($stagingJob.State -ne 'Completed') {
                                $reason = $stagingJob.ChildJobs[0].JobStateInfo.Reason.Message
                                throw "Portable fallback staging failed for $($Tool.id): $reason"
                            }
                            Receive-Job -Job $stagingJob -ErrorAction Stop | Out-Null
                        }
                        finally {
                            if ($stagingJob.State -in @('NotStarted', 'Running')) { Stop-Job -Job $stagingJob }
                            Remove-Job -Job $stagingJob -Force
                        }
                        Write-Phase "Staged $($Tool.id) in $([int]((Get-Date) - $stagingStarted).TotalSeconds)s."
                    }
                    else {
                        Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $installRoot -Recurse -Force
                    }
                }
                finally {
                    if ($process) { $process.Dispose() }
                    if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
                }
            }
            'exe' {
                $arguments = @($fallback.arguments | ForEach-Object { ([string]$_).Replace('{installRoot}', $installRoot) })
                & $artifact @arguments | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "Portable fallback installer failed for $($Tool.id) (exit $LASTEXITCODE)." }
            }
            'file' { Copy-Item -LiteralPath $artifact -Destination $commandPath -Force }
        }
    }
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) { throw "Portable fallback did not provide the declared command for $($Tool.id): $commandPath" }
    Add-ToolPath (Split-Path -Parent $commandPath)
    foreach ($relativePath in @($fallback.additionalPathRelativePaths)) {
        Add-ToolPath (Join-Path $installRoot ([string]$relativePath).Replace('/', '\'))
    }
    Write-Phase "Using canonical fallback for $($Tool.id) $($Tool.version) at $commandPath."
    return $commandPath
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

# Validate the complete top-level allowlist before any package or Git network call.
$gitmodulesPath = Join-Path $repoRoot '.gitmodules'
$registeredModules = @(Get-GitmoduleEntries $gitmodulesPath)
if ($registeredModules.Count -ne @($manifest.submodules).Count) { throw 'The .gitmodules entry count differs from the exact public allowlist.' }
foreach ($expected in @($manifest.submodules)) {
    $matches = @($registeredModules | Where-Object { $_.name -eq [string]$expected.name -and $_.path -eq [string]$expected.path -and $_.url -eq [string]$expected.url })
    if ($matches.Count -ne 1) { throw "The .gitmodules entry is not exactly allowlisted: $($expected.name)." }
}
foreach ($excluded in @($manifest.excludedGitlinks)) {
    if (@($registeredModules.path) -contains [string]$excluded) { throw "Excluded private gitlink is registered as a submodule: $excluded" }
}

$toolRoot = if ($QtRootOverride) { Split-Path -Parent $QtRootOverride } else { Join-Path $repoRoot $manifest.toolRoot }
$qtRoot = if ($QtRootOverride) { $QtRootOverride } else { Join-Path $toolRoot 'Qt' }
$qtInstallRoot = Get-QtInstallRoot $manifest $qtRoot
if ($ValidateQtCacheOnly) {
    $missingQt = @(Get-MissingQtProofs $manifest $qtInstallRoot)
    if ($missingQt.Count -ne 0) { throw "Qt cache is incomplete: $($missingQt -join ', ')." }
    Write-Phase "Qt cache is complete for every declared module at $qtInstallRoot."
    exit 0
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

$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
$resolvedTools = @{}
foreach ($tool in $manifest.winget) {
    $fallbackCommand = Resolve-FallbackTool $tool $toolRoot
    if ($fallbackCommand) {
        $resolvedTools[[string]$tool.command] = Install-FallbackTool $tool $toolRoot
        continue
    }

    $wingetFailure = if ($winget) { $null } else { 'winget.exe is unavailable' }
    if ($winget) {
        $catalog = & $winget.Source show --exact --id ([string]$tool.id) --version ([string]$tool.version) --source winget --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -eq 0) {
            $catalogHashLine = $catalog | Select-String -Pattern '^\s*Installer SHA256:\s*([0-9a-fA-F]{64})\s*$' | Select-Object -First 1
            if (-not $catalogHashLine -or $catalogHashLine.Matches[0].Groups[1].Value.ToLowerInvariant() -ne ([string]$tool.sha256).ToLowerInvariant()) {
                throw "winget catalog digest does not match dependencies.manifest.json for $($tool.id) $($tool.version)."
            }
            $existing = Resolve-Tool $tool.command
            & $winget.Source list --exact --id ([string]$tool.id) --version ([string]$tool.version) --source winget --accept-source-agreements --disable-interactivity *> $null
            if ($existing -and $LASTEXITCODE -eq 0) {
                Write-Phase "Found exact $($tool.id) $($tool.version) at $existing; reusing it."
                $resolvedTools[[string]$tool.command] = $existing
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
            if ($LASTEXITCODE -eq 0) {
                $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
                $env:Path = "$machinePath;$userPath;$env:Path"
                $installedCommand = Resolve-Tool $tool.command
                if ($installedCommand) {
                    $resolvedTools[[string]$tool.command] = $installedCommand
                    continue
                }
                $wingetFailure = 'winget exited successfully but the declared command was unavailable'
            }
            else {
                $wingetFailure = "winget install exited $LASTEXITCODE"
            }
        }
        else {
            $wingetFailure = "winget show exited $LASTEXITCODE"
        }
    }

    if ($tool.fallback) {
        Write-Phase "$wingetFailure for $($tool.id) $($tool.version); switching to its declared canonical fallback."
        $resolvedTools[[string]$tool.command] = Install-FallbackTool $tool $toolRoot
        continue
    }

    if ([string]$tool.command -eq 'vswhere') {
        $vswhere = Resolve-Tool 'vswhere'
        if ($vswhere) {
            $compatibleVisualStudio = & $vswhere -latest -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($compatibleVisualStudio | Select-Object -First 1))) {
                Write-Phase "$wingetFailure for $($tool.id) $($tool.version); reusing the compatible installed Visual Studio 2022 C++ toolchain."
                $resolvedTools[[string]$tool.command] = $vswhere
                continue
            }
        }
    }
    throw "$wingetFailure for $($tool.id) $($tool.version), no declared fallback is available, and no compatible installed toolchain was found."
}

# Refresh only this process. Package-manager changes normally affect future shells.
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath;$env:Path"

$python = $resolvedTools['py']
if (-not $python) { $python = Resolve-Tool 'py' }
if (-not $python) { throw 'Python 3.11 bootstrap completed but no declared Python command is available.' }
$venv = Join-Path $toolRoot 'python'
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Phase "Creating the project-local Python tool environment at $venv."
    if ([IO.Path]::GetFileName($python) -ieq 'py.exe') { & $python -3.11 -m venv $venv | Out-Host }
    else { & $python -m venv $venv | Out-Host }
    if ($LASTEXITCODE -ne 0) { throw 'Python could not create the project-local tool environment.' }
}
foreach ($package in $manifest.python.packages) {
    Write-Phase "Ensuring Python package $package is installed."
    & $venvPython -m pip install --disable-pip-version-check --no-input $package | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Python package installation failed: $package" }
}

$qtVersion = [string]$manifest.qt.version
$qtArch = [string]$manifest.qt.architecture
$missingQt = @(Get-MissingQtProofs $manifest $qtInstallRoot)
if ($missingQt.Count -ne 0) {
    Write-Phase "Qt cache is missing declared proofs ($($missingQt -join ', ')); repairing the complete declared set."
    Write-Phase "Installing Qt $qtVersion ($qtArch) and declared modules into $qtRoot."
    $qtArguments = @(
        '-m', 'aqt', 'install-qt', [string]$manifest.qt.host,
        [string]$manifest.qt.target, $qtVersion, $qtArch,
        '-O', $qtRoot, '--modules'
    ) + @($manifest.qt.modules)
    & $venvPython @qtArguments | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Qt $qtVersion installation failed." }
}
$missingQt = @(Get-MissingQtProofs $manifest $qtInstallRoot)
if ($missingQt.Count -ne 0) {
    throw "Qt installation completed with missing declared proofs: $($missingQt -join ', ')."
}

$pacman = $resolvedTools['pacman']
if (-not $pacman) { $pacman = Resolve-Tool 'pacman' }
if (-not $pacman) { throw 'MSYS2 bootstrap completed but pacman.exe is unavailable.' }
$msysUsrBin = Split-Path -Parent $pacman
$msysRoot = Split-Path -Parent (Split-Path -Parent $msysUsrBin)
$msysBash = Join-Path $msysUsrBin 'bash.exe'
$pacmanKey = Join-Path $msysUsrBin 'pacman-key'
$keyringRoot = Join-Path $msysRoot 'usr\share\pacman\keyrings'
foreach ($keyringFile in @('msys2.gpg', 'msys2-trusted', 'msys2-revoked')) {
    $keyringPath = Join-Path $keyringRoot $keyringFile
    if (-not (Test-Path -LiteralPath $keyringPath -PathType Leaf)) { throw "Bundled official MSYS2 keyring material is missing: $keyringPath" }
}
if (-not (Test-Path -LiteralPath $msysBash -PathType Leaf)) { throw "MSYS2 bash.exe is unavailable for keyring initialization: $msysBash" }
if (-not (Test-Path -LiteralPath $pacmanKey -PathType Leaf)) { throw "Bundled MSYS2 pacman-key script is unavailable: $pacmanKey" }
Write-Phase 'Initializing and populating the package keyring from bundled official MSYS2 material.'
& $msysBash '/usr/bin/pacman-key' --init | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 keyring initialization failed (exit $LASTEXITCODE)." }
& $msysBash '/usr/bin/pacman-key' --populate msys2 | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 keyring population failed (exit $LASTEXITCODE)." }
Write-Phase 'Refreshing the MSYS2 package database and installing the pinned manifest package set.'
& $pacman -Syu --noconfirm | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 database refresh failed (exit $LASTEXITCODE)." }
Write-Phase 'Continuing the MSYS2 runtime upgrade in a fresh pacman process before package installation.'
& $pacman -Su --noconfirm | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 runtime upgrade continuation failed (exit $LASTEXITCODE)." }
& $pacman -S --needed --noconfirm @($manifest.msys2.packages) | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MSYS2 package installation failed (exit $LASTEXITCODE)." }

Write-Phase 'Initializing only public, manifest-listed submodules.'
$git = $resolvedTools['git']
if (-not $git) { $git = Resolve-Tool 'git' }
if (-not $git) { throw 'Git bootstrap completed but git.exe is unavailable.' }
& $git -C $repoRoot submodule sync -- @($manifest.submodules.path) | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Public submodule synchronization failed.' }
& $git -C $repoRoot submodule update --init --jobs 4 -- @($manifest.submodules.path) | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Public submodule initialization failed.' }

$elapsed = (Get-Date) - $startedAt
Write-Phase ("Complete in {0:hh\:mm\:ss}. Tool root: {1}" -f $elapsed, $toolRoot)
