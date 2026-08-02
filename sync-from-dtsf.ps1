<#
.SYNOPSIS
  Refresh the published artefacts from the upstream DTSF monorepo.

.DESCRIPTION
  Two files are maintained in the DTSF monorepo and republished here:

    index.html  <- twins/packs/diplomacy-table/diplomacy-table-config.html
    app.html    <- twins/packs/diplomacy-table/diplomacy-table-app.html

  Each is published with exactly one line added: the DTSF_API_BASE_DEFAULT
  declaration that keeps a Pages build in reference-only mode.

  This script copies each upstream file, injects that line, and verifies the
  result — including that no secret-shaped string and no external resource
  reference has crept in, since anything here is published publicly.

  It also validates `runs/` if present. Those files are not synced — DTSF's
  scripts/export-diplomacy-run.mjs writes them here directly — but they are
  published, so they are checked at the same gate as everything else.

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

$fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
  Write-Host ("  {0}  {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name)
  if (-not $ok) {
    $script:fail++
    if ($detail) { Write-Host ("        " + $detail) -ForegroundColor DarkYellow }
  }
}

function Sync-Artefact {
  param(
    [string]$SourceName,
    [string]$TargetName,
    [string]$AnchorPattern,
    [scriptblock]$ExtraChecks
  )

  $source = Join-Path $DtsfRoot ("twins\packs\diplomacy-table\" + $SourceName)
  if (-not (Test-Path $source)) { throw "Upstream artefact not found: $source" }

  $target = Join-Path $PSScriptRoot $TargetName
  $html = Get-Content $source -Raw

  # Inject immediately after the <title>, which puts the declaration before the
  # main script block in every layout these files have used.
  $m = [regex]::Match($html, $AnchorPattern)
  if (-not $m.Success) {
    throw "Could not find the injection anchor in $SourceName. The upstream markup changed; update this script."
  }
  $anchor = $m.Value

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

  Write-Host ""
  Write-Host ("{0}  <-  {1}" -f $TargetName, $SourceName)

  $out = Get-Content $target -Raw

  Check 'config line injected'        ($out -match [regex]::Escape("DTSF_API_BASE_DEFAULT = '$ApiBase'"))
  Check 'injected before the resolver' ($out.IndexOf('DTSF_API_BASE_DEFAULT') -lt $out.IndexOf('function resolveBase'))
  Check 'resolver uses presence test'  ($out -match "'DTSF_API_BASE_DEFAULT' in window")
  Check 'no external resources'        (-not ($out -match '(?i)(src|href)="(https?:)?//'))
  Check 'no secret-shaped strings'     (-not ($out -match '(gh[pousr]_[A-Za-z0-9]{16,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-)'))

  # Extract script blocks exactly the way an HTML tokenizer does — from a
  # <script> start tag to the NEXT literal end tag, regardless of JavaScript
  # string or comment context — and syntax-check each one.
  #
  # This is not pedantry. An end-script tag written inside a JS comment silently
  # ends the script element there; every line below is dropped and the remainder
  # of the file renders as text. It shipped in one of these files once, looked
  # completely fine to a string-matching check, and was caught only by executing
  # the page. Write such sequences escaped, as <\/script>.
  $scriptBodies = [regex]::Matches($out, '(?s)<script\b[^>]*>(.*?)</script>')
  Check 'script blocks recoverable' ($scriptBodies.Count -ge 2) "found $($scriptBodies.Count)"

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("dtl-" + [Guid]::NewGuid().ToString('N') + ".js")
  $syntaxOk = $true
  $syntaxMsg = ''
  foreach ($blk in $scriptBodies) {
    $blk.Groups[1].Value | Set-Content $tmp -NoNewline -Encoding utf8
    $null = & node --check $tmp 2>&1
    if ($LASTEXITCODE -ne 0) { $syntaxOk = $false; $syntaxMsg = "block at offset $($blk.Index) does not parse" }
  }
  Remove-Item $tmp -ErrorAction SilentlyContinue
  Check 'every script block parses as JavaScript' $syntaxOk $syntaxMsg

  # Anything after the final close tag should be closing markup only. If a
  # script was truncated early, orphaned JavaScript ends up here as page text.
  $tail = $out.Substring($out.LastIndexOf('</script>') + 9)
  Check 'no orphaned code after last script' (-not ($tail -match '(?m)^\s*(function|var|const|let)\s')) `
    ($tail.Trim() -replace '\s+', ' ')

  Check 'document closes cleanly' ($out.TrimEnd().EndsWith('</html>'))

  if ($ExtraChecks) { & $ExtraChecks $out }

  return $target
}

$consoleTarget = Sync-Artefact -SourceName 'diplomacy-table-config.html' -TargetName 'index.html' `
  -AnchorPattern '<title>Diplomacy Table [^<]*Configuration[^<]*</title>' `
  -ExtraChecks {
    param($out)
    Check 'nav buttons match tab sections' (
      ([regex]::Matches($out, 'data-tab="')).Count -eq ([regex]::Matches($out, 'class="tab[ "]')).Count
    )
  }

$appTarget = Sync-Artefact -SourceName 'diplomacy-table-app.html' -TargetName 'app.html' `
  -AnchorPattern '<title>[^<]*</title>' `
  -ExtraChecks {
    param($out)
    # The app is a live control surface, so unlike the console it must not try
    # to reach a backend that is not there. Two invariants keep it honest.
    $scripts = ([regex]::Matches($out, '(?s)<script\b[^>]*>(.*?)</script>') |
      ForEach-Object { $_.Groups[1].Value }) -join "`n"

    # Two calls legitimately bypass apiUrl(), and both exist precisely because
    # there is no backend: the replay log and the run manifest are static files
    # beside this page, and apiUrl() throws in a reference-only build by design.
    # Each is marked at the call site. Anything unmarked is a real leak, and a
    # THIRD exemption is a decision someone must make deliberately rather than
    # inherit from a loosened check.
    $direct = [regex]::Matches($scripts, 'fetch\(\s*(?!apiUrl\()')
    $unmarked = @()
    $exempt = 0
    foreach ($m in $direct) {
      $from = [Math]::Max(0, $m.Index - 320)
      if ($scripts.Substring($from, $m.Index - $from) -match 'dtsf-allow-direct-fetch') { $exempt++ }
      else { $unmarked += $m.Index }
    }
    Check 'every fetch() goes through apiUrl() or is marked exempt' ($unmarked.Count -eq 0) `
      "unmarked direct fetch at offset(s): $($unmarked -join ', ')"
    Check 'exactly the two known offline reads are exempt' ($exempt -eq 2) "found $exempt"

    Check 'no window.location.origin base' (-not ($scripts -match 'BASE\s*=\s*window\.location\.origin'))
    Check 'reference-only boot guard present' ($scripts -match 'if \(!BASE\)')
    Check 'replay gallery wired to the no-backend path' ($scripts -match 'loadRunManifest\(\)\.then')
  }

# ---------------------------------------------------------------------------
# Recorded runs (DIPL-TICK-005)
#
# These are not synced — `scripts/export-diplomacy-run.mjs` in DTSF writes them
# here directly — but they ARE published, so they are checked here, at the same
# gate as everything else. A published run is a transcript: the one thing that
# must never be wrong about it is whose eyes it represents.
# ---------------------------------------------------------------------------

$runsDir = Join-Path $PSScriptRoot 'runs'
if (Test-Path $runsDir) {
  Write-Host ''
  Write-Host 'runs/'

  $manifestPath = Join-Path $runsDir 'index.json'
  Check 'run manifest present' (Test-Path $manifestPath) 'runs/ exists but has no index.json - the gallery will not appear'

  if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    $onDisk = @(Get-ChildItem $runsDir -Filter *.ndjson | ForEach-Object { $_.Name })
    $listed = @($manifest.runs | ForEach-Object { $_.file })

    $missing = @($listed | Where-Object { $onDisk -notcontains $_ })
    Check 'every listed run exists on disk' ($missing.Count -eq 0) "missing: $($missing -join ', ')"

    $unlisted = @($onDisk | Where-Object { $listed -notcontains $_ })
    Check 'every run on disk is listed' ($unlisted.Count -eq 0) `
      "not in index.json (re-run export-diplomacy-run.mjs --manifest-only): $($unlisted -join ', ')"

    $noPerspective = @($manifest.runs | Where-Object { -not $_.perspective -or $_.perspective -eq 'unknown' } |
      ForEach-Object { $_.file })
    Check 'every run declares a perspective' ($noPerspective.Count -eq 0) "undeclared: $($noPerspective -join ', ')"
  }

  foreach ($run in Get-ChildItem $runsDir -Filter *.ndjson) {
    $raw = Get-Content $run.FullName -Raw
    Check ("no secret-shaped strings in " + $run.Name) `
      (-not ($raw -match '(gh[pousr]_[A-Za-z0-9]{16,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-)'))

    $first = ($raw -split "`n" | Where-Object { $_.Trim() })[0]
    $ok = $false
    try { $ok = (($first | ConvertFrom-Json).kind -eq 'header') } catch { $ok = $false }
    Check ("first line of " + $run.Name + " is the header") $ok `
      'the player refuses a log that does not open by declaring its perspective'
  }
}

Write-Host ''
if ($fail -gt 0) { throw "$fail check(s) failed — do not publish this build." }

foreach ($t in @($consoleTarget, $appTarget)) {
  Write-Host ("Synced {0,7:N0} KB  {1}" -f ((Get-Item $t).Length / 1KB), (Split-Path $t -Leaf))
}
if ($ApiBase -eq '') { Write-Host 'Build is reference-only (no backend).' }
else { Write-Host "Build points at $ApiBase" }
