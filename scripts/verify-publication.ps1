[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

$required = @(
    'README.md',
    'SECURITY.md',
    'LICENSE',
    'EVIDENCE_MANIFEST.md',
    'REPORT_QA.md',
    'evidence/README.md',
    'evidence/test-summary.json',
    'evidence/coverage-summary.json',
    'evidence/coverage.json',
    'evidence/slither-summary.json',
    'evidence/slither-0.11.5.json',
    'reports/AEGENT-Security-Assessment-Core-2026-07.md',
    'reports/AEGENT-Security-Assessment-Core-2026-07.docx',
    'reports/AEGENT-Security-Assessment-Core-2026-07.pdf',
    'reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.md',
    'reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.docx',
    'reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.pdf',
    'reports/AEGENT-Security-Assessment-Threat-Model-2026-07.md',
    'reports/AEGENT-Security-Assessment-Threat-Model-2026-07.docx',
    'reports/AEGENT-Security-Assessment-Threat-Model-2026-07.pdf',
    'reports/AEGENT-CertiK-Security-Assessment-2026-07.docx',
    'reports/AEGENT-CertiK-Security-Assessment-2026-07.pdf',
    'reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.docx',
    'reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.pdf',
    'reports/AEGENT-SlowMist-Security-Assessment-2026-07.docx',
    'reports/AEGENT-SlowMist-Security-Assessment-2026-07.pdf',
    'reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.docx',
    'reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.pdf',
    'reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.docx',
    'reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.pdf',
    'reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.docx',
    'reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.pdf',
    'source-snapshot/contracts/AegentMarketRegistry.sol',
    'source-snapshot/contracts/AegentRedemptionV2.sol',
    'source-snapshot/contracts/AegentSaleProceedsVault.sol',
    'source-snapshot/contracts/AegentSwapV2.sol',
    'source-snapshot/contracts/interfaces/IAegentMarketRegistry.sol',
    'source-snapshot/contracts/interfaces/IAegentPurchaseReceiptSource.sol',
    'source-snapshot/contracts/interfaces/IAegentRedemptionEndpoint.sol',
    'source-snapshot/contracts/interfaces/IAegentRegistryBound.sol',
    'source-snapshot/contracts/interfaces/IAegentSaleProceedsVault.sol',
    'source-snapshot/contracts/interfaces/IAggregatorV3.sol',
    'test-snapshot/AegentRedemptionV2.test.cjs',
    'test-snapshot/AegentSwapV2.test.cjs',
    'test-snapshot/AegentV2Integration.test.cjs'
)

$missing = @(
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf)) {
            $relative
        }
    }
)
if ($missing.Count -gt 0) {
    throw "Missing required publication files: $($missing -join ', ')"
}

$files = Get-ChildItem -LiteralPath $repo -Recurse -Force -File |
    Where-Object {
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/](docs|rendered)[\\/]'
    }

$oversized = @($files | Where-Object Length -GE 100MB)
if ($oversized.Count -gt 0) {
    throw "Files at or above 100 MB: $($oversized.FullName -join ', ')"
}

$sensitiveNames = '(?i)(^|[._-])(private[-_]?key|seed|mnemonic|wallet|keystore|credential|secret|token|cookie)([._-]|$)|\.env$|\.pem$|\.p12$|\.pfx$|id_rsa|id_ed25519'
$sensitive = @($files | Where-Object { $_.Name -match $sensitiveNames })
if ($sensitive.Count -gt 0) {
    throw "Sensitive-looking filenames detected: $($sensitive.FullName -join ', ')"
}

$thirdPartyBrandAssets = @(
    $files | Where-Object {
        $_.Extension -match '^\.(png|jpg|jpeg|svg|webp)$' -and
        $_.Name -match '(?i)(certik|slowmist|openzeppelin)'
    }
)
if ($thirdPartyBrandAssets.Count -gt 0) {
    throw "Third-party audit-company brand assets detected: $($thirdPartyBrandAssets.FullName -join ', ')"
}

$textExtensions = @('.md', '.json', '.ps1', '.sol', '.cjs', '.gitignore')
$textFiles = @(
    $files | Where-Object {
        $textExtensions -contains $_.Extension.ToLowerInvariant() -or $_.Name -eq '.gitignore'
    }
)
$privateMarkers = @(
    ('C:' + '\Users'),
    ('C:' + '/Users'),
    ('财源' + '广进'),
    ('Aegent_' + '完整项目'),
    ('Desktop' + '\01-项目工程'),
    ('Desktop' + '/01-项目工程')
)
foreach ($file in $textFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($text.Contains([char]0xFFFD)) {
        throw "Unicode replacement character detected in $($file.FullName)"
    }
    foreach ($marker in $privateMarkers) {
        if ($text.Contains($marker)) {
            throw "Machine-private path marker '$marker' detected in $($file.FullName)"
        }
    }
}

$reportText = Get-ChildItem -LiteralPath (Join-Path $repo 'reports') -Filter '*.md' -File |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }
$combined = $reportText -join "`n"

foreach ($expected in @(
    'Author and issuer:** AEGENT Security Review Team',
    'remediation required before mainnet',
    'not authored, reviewed, endorsed, signed, certified, or issued by'
)) {
    if ($combined -notmatch [regex]::Escape($expected)) {
        throw "Required attribution or disposition text missing: $expected"
    }
}

foreach ($id in @('MED-01', 'MED-02', 'MED-03', 'LOW-01', 'INFO-01', 'INFO-02', 'INFO-03')) {
    if ($combined -notmatch [regex]::Escape($id)) {
        throw "Finding identifier missing from reports: $id"
    }
}

$publicReportBase = 'https://github.com/yxmail888-boop/aegent-security-reports/blob/main/'
if ($combined -match '\]\((?:\.\./)+(?:source-snapshot|test)/' -or
    $combined -match '\]\((?:source-snapshot|test)/') {
    throw 'Relative source or test hyperlinks remain in public report Markdown.'
}
if ($combined -notmatch [regex]::Escape("${publicReportBase}source-snapshot/") -or
    $combined -notmatch [regex]::Escape("${publicReportBase}test-snapshot/")) {
    throw 'Expected absolute public GitHub source/test links are missing from reports.'
}

$manifestPath = Join-Path $repo 'EVIDENCE_MANIFEST.md'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
$manifestRows = [regex]::Matches(
    $manifest,
    '(?m)^\| `(?<path>[^`]+)` \| `(?<hash>[0-9a-f]{64})` \| (?<bytes>[\d,]+) \|\r?$'
)
if ($manifestRows.Count -lt 29) {
    throw "Evidence manifest contains only $($manifestRows.Count) hashed artifact rows."
}
foreach ($row in $manifestRows) {
    $relative = $row.Groups['path'].Value
    $artifact = Join-Path $repo $relative
    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) {
        throw "Manifest artifact is missing: $relative"
    }
    $expectedHash = $row.Groups['hash'].Value
    $actualHash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "Manifest hash mismatch: $relative"
    }
    $expectedBytes = [int64]($row.Groups['bytes'].Value.Replace(',', ''))
    $actualBytes = (Get-Item -LiteralPath $artifact).Length
    if ($actualBytes -ne $expectedBytes) {
        throw "Manifest byte-count mismatch: $relative"
    }
}

Write-Output "Publication verification passed: $($files.Count) files, $($manifestRows.Count) manifest hashes, 0 oversized, 0 sensitive-name matches, 0 private-path markers."
