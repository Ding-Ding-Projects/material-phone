[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$WithAttribution
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$extensions = @('.bat', '.c', '.cc', '.cmake', '.cpp', '.css', '.h', '.hpp', '.html', '.js', '.json', '.md', '.ps1', '.py', '.qml', '.sh', '.ts', '.xml', '.yml', '.yaml')
$excludedPrefixes = @('external/', 'build/', '.tools/')
$files = @(& git -C $repoRoot ls-files | Where-Object {
    $path = $_.Replace('\', '/')
    $extension = [IO.Path]::GetExtension($path).ToLowerInvariant()
    $extensions -contains $extension -and -not ($excludedPrefixes | Where-Object { $path.StartsWith($_) })
})

function Get-Category([string]$Path) {
    $p = $Path.Replace('\', '/')
    if ($p -match '(^|/)(test|tests|tester)(/|$)' -or $p -match '\.(spec|test)\.') { return 'Tests' }
    if ($p -match '\.(css|html|qml|xml)$') { return 'Styles and markup' }
    if ($p -match '^(\.github/|cmake/|scripts/)' -or $p -match '(^|/)CMakeLists\.txt$' -or $p -match '\.bat$') { return 'Build and delivery' }
    if ($p -match '\.md$') { return 'Documentation' }
    if ($p -match '\.(c|cc|cpp|h|hpp|js|py|ts)$') { return 'Application source' }
    return 'Other project files'
}

$rows = [ordered]@{}
foreach ($file in $files) {
    $fullPath = Join-Path $repoRoot $file
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
    $lines = [IO.File]::ReadAllLines($fullPath)
    $category = Get-Category $file
    if (-not $rows.Contains($category)) { $rows[$category] = [ordered]@{ Total = 0; NonBlank = 0 } }
    $rows[$category].Total += $lines.Count
    $rows[$category].NonBlank += @($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

$markdown = @(
    '# Project line count',
    '',
    '| Category | Total lines | Non-blank lines |',
    '|---|---:|---:|'
)
$grandTotal = 0
$grandNonBlank = 0
foreach ($entry in $rows.GetEnumerator()) {
    $grandTotal += $entry.Value.Total
    $grandNonBlank += $entry.Value.NonBlank
    $markdown += "| $($entry.Key) | $($entry.Value.Total) | $($entry.Value.NonBlank) |"
}
$markdown += "| **Project total** | **$grandTotal** | **$grandNonBlank** |"
$markdown += ''
$markdown += 'Excluded: submodules, third-party trees, dependency caches, and generated build output.'
$markdown += 'Command: `powershell.exe -NoProfile -File scripts/count-lines.ps1 -WithAttribution`'

if ($WithAttribution) {
    $agent = 0
    $people = 0
    foreach ($file in $files) {
        $blame = @(& git -C $repoRoot blame --line-porcelain HEAD -- $file 2>$null)
        foreach ($line in $blame) {
            if ($line -notmatch '^author-mail <(.+)>$') { continue }
            if ($Matches[1] -eq 'noreply@anthropic.com' -or $Matches[1] -match '(bot|automation)') { $agent++ } else { $people++ }
        }
    }
    $attributed = $agent + $people
    $markdown += ''
    $markdown += '## Surviving-line attribution'
    $markdown += ''
    $markdown += '| Attribution | Lines |'
    $markdown += '|---|---:|'
    $markdown += "| Automation-authored | $agent |"
    $markdown += "| Person-authored | $people |"
    $markdown += "| **Attributed total** | **$attributed** |"
    $markdown += ''
    $markdown += 'Attribution uses surviving lines from `git blame`; automation identities include the configured agent author and bot-like author emails.'
}

$result = $markdown -join [Environment]::NewLine
if ($OutputPath) {
    $parent = Split-Path -Parent $OutputPath
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Set-Content -LiteralPath $OutputPath -Value $result -Encoding utf8
}
$result
