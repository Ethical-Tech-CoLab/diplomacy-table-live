<#
.SYNOPSIS
  Refresh index.html from the upstream DTSF artefact.

.DESCRIPTION
  The console is maintained in the DTSF monorepo and served there at
  GET /diplomacy-table/config. This repo publishes the same file with exactly
  one line added: the DTSF_API_BASE_DEFAULT declaration that keeps a Pages
  build in reference-only mode.

  This script copies the upstream file, re-injects that line, and verifies the
  result — including that no secret-shaped string and no external resource
  reference has crept in, since anything in this file is published publicly.

.PARAMETER DtsfRoot
  Path to the DTSF monorepo checkout.

.PARAMETER ApiBase
  Backend URL to bake into the build. Defaults to '' (reference-only), which is
  a meaningful value — see README.

.EXAMPLE
  .\sync-from-dtsf.ps1 -DtsfRoot C:\Dev\dtsf
  .\sync-from-dtsf.ps1 -DtsfRoot C:\Dev\dtsf -ApiBase https://dtsf.example.org
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$DtsfRoot,
  [string]$ApiBase = ''
)

$ErrorActionPreference = 'Stop'

$source = Join-Path $DtsfRoot 'twins\packs\diplomacy-table\diplomacy-table-config.html'
if (-not (Test-Path $source)) { throw "Upstream artefact not found: $source" }

$target = Join-Path $PSScriptRoot 'index.html'
$html = Get-Content $source -Raw

$anchor = '<title>Diplomacy Table &mdash; Configuration &amp; Teaching Console</title>'
if (-not $html.Contains($anchor)) {
  $anchor = "<title>Diplomacy Table $([char]0x2014) Configuration &amp; Teaching Console</title>"
}
if (-not $html.Contains($anchor)) {
  throw 'Could not find the <title> injection anchor. The upstream title changed; update this script.'
}

$block = @"
$anchor

<!-- Deployment configuration (GitHub Pages build).
     The ONLY difference between this file and the copy served by the DTSF
     runtime. Empty string = "there is deliberately no backend at this origin";
     resolveBase() tests for the property's presence, not its truthiness. -->
<script>window.DTSF_API_BASE_DEFAULT = '$ApiBase';</script>
"@

$html = $html.Replace($anchor, $block)
$html | Set-Content $target -NoNewline -Encoding utf8

# ---- verification -----------------------------------------------------------
$out = Get-Content $target -Raw
$fail = 0
function Check([string]$name, [bool]$ok) {
  Write-Host ("{0}  {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name)
  if (-not $ok) { $script:fail++ }
}

Check 'config line injected'      ($out -match [regex]::Escape("DTSF_API_BASE_DEFAULT = '$ApiBase'"))
Check 'injected before main script' ($out.IndexOf('DTSF_API_BASE_DEFAULT') -lt $out.IndexOf('function resolveBase'))
Check 'resolver uses presence test' ($out -match "'DTSF_API_BASE_DEFAULT' in window")
Check 'no external resources'     (-not ($out -match '(?i)(src|href)="(https?:)?//'))
Check 'no secret-shaped strings'  (-not ($out -match '(gh[pousr]_[A-Za-z0-9]{16,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})'))
Check 'nav buttons match sections' (
  ([regex]::Matches($out, 'data-tab="')).Count -eq ([regex]::Matches($out, 'class="tab[ "]')).Count
)

# Extract script blocks exactly the way an HTML tokenizer does — from a
# <script> start tag to the NEXT literal `</script>`, regardless of JavaScript
# string or comment context — and syntax-check each one.
#
# This is not pedantry. A `</script>` written inside a JS comment silently ends
# the script element there; every line below is dropped and the remainder of the
# file renders as text. It shipped in this file once, looked completely fine in
# a string-matching check, and was only caught by executing the page. Write such
# sequences as <\/script>.
$scriptBodies = [regex]::Matches($out, '(?s)<script\b[^>]*>(.*?)</script>')
Check 'script blocks recoverable' ($scriptBodies.Count -ge 2) "found $($scriptBodies.Count)"

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("dtl-" + [Guid]::NewGuid().ToString('N') + ".js")
$syntaxOk = $true
$syntaxMsg = ''
foreach ($m in $scriptBodies) {
  $m.Groups[1].Value | Set-Content $tmp -NoNewline -Encoding utf8
  $null = & node --check $tmp 2>&1
  if ($LASTEXITCODE -ne 0) { $syntaxOk = $false; $syntaxMsg = "block at offset $($m.Index) does not parse" }
}
Remove-Item $tmp -ErrorAction SilentlyContinue
Check 'every script block parses as JavaScript' $syntaxOk $syntaxMsg

# Anything after the final </script> should be closing markup only. If a script
# was truncated early, orphaned JavaScript ends up here as page text.
$tail = $out.Substring($out.LastIndexOf('</script>') + 9)
Check 'no orphaned code after last script' (-not ($tail -match '(?m)^\s*(function|var|const|let)\s')) `
  ($tail.Trim() -replace '\s+', ' ')

# The last thing in the file should still be the closing markup, not orphaned JS.
Check 'document closes cleanly' ($out.TrimEnd().EndsWith('</html>'))

Write-Host ''
if ($fail -gt 0) { throw "$fail check(s) failed — do not publish this build." }
Write-Host ("Synced {0:N0} KB from {1}" -f ((Get-Item $target).Length / 1KB), $source)
if ($ApiBase -eq '') { Write-Host 'Build is reference-only (no backend).' }
else { Write-Host "Build points at $ApiBase" }
