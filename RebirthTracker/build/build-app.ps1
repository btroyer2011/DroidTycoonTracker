# build-app.ps1 - inline the chart data and the sprite library into a single self-contained
# index.html. Nothing external is referenced, so the one file works offline and can just be
# copied to a phone.

$ErrorActionPreference = "Stop"

$COSTS = @("10K","150K","975K","2.95M","5.35M","9.85M","14.5M","36M","89M","220M",
           "550M","1.36B","3.4B","8.45B","21B","52B","130B","325B","810B","2T",
           "3T","4.5T","6T","9T","13.5T","21T","32T","45T","68T","100T")

# Crystal (gem) reward granted at each rebirth. Levels 1-11 award none; rewards begin at 12.
# Read from the poster reward column and verified identical across cycles 1 and 3, same as
# the money costs. Stored as (level, crystals) pairs - NOT an [ordered] hashtable, because
# integer-keyed dictionaries index by position, not key, which silently corrupts the values.
$CRYSTALS = @(
    @(12,11),  @(13,16),  @(14,22),  @(15,29),  @(16,37),  @(17,46),  @(18,56),  @(19,67),  @(20,79),
    @(21,92),  @(22,106), @(23,121), @(24,137), @(25,154), @(26,172), @(27,191), @(28,221), @(29,232), @(30,254)
)

# Upgrade Chips Costs, verbatim from the posters' Additional Info panel (identical on all four)
$CHIP_COLS = @("Gold","Diamond","Rainbow","Beskar","Galactic")
$CHIP_ROWS = @(
    @("Common",   10,   25,    40,    80,   120),
    @("Rare",     30,   60,   100,   250,   400),
    @("Epic",    120,  180,   240,  3000,  6000),
    @("Legend",  400, 1200,  3000,  7500, 20000),
    @("Mythic", 4000, 8000, 20000, 40000, 70000)
)

$VERSION = "Update v1.23 (25 Jul 2026)"

# --- chart data ------------------------------------------------------------------------
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("var COSTS=" + ($COSTS | ConvertTo-Json -Compress) + ";")
$cryPairs = $CRYSTALS | ForEach-Object { "$($_[0]):$($_[1])" }
[void]$sb.AppendLine("var CRYSTALS={" + ($cryPairs -join ",") + "};")
[void]$sb.AppendLine("var META={version:" + ($VERSION | ConvertTo-Json -Compress) + "};")
[void]$sb.AppendLine("var CHIPS={cols:" + ($CHIP_COLS | ConvertTo-Json -Compress) + ",rows:[")
foreach ($r in $CHIP_ROWS) { [void]$sb.AppendLine("[" + (($r | ForEach-Object { $_ | ConvertTo-Json -Compress }) -join ",") + "],") }
[void]$sb.AppendLine("]};")

[void]$sb.AppendLine("var CYCLES={")
foreach ($c in 1..4) {
    $data = [System.IO.File]::ReadAllText((Resolve-Path (Join-Path $PSScriptRoot "cycle$c.json")).Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($data.levels.Count -ne 30) { throw "cycle ${c}: expected 30 levels, got $($data.levels.Count)" }
    [void]$sb.AppendLine("${c}:[")
    foreach ($lvRow in $data.levels) {
        if ($lvRow.Count -ne 3) { throw "cycle ${c}: a level does not have 3 droids" }
        $cells = $lvRow | ForEach-Object {
            '{n:' + ($_.n | ConvertTo-Json -Compress) + ',r:"' + $_.r + '",b:"' + $_.b + '"}'
        }
        [void]$sb.AppendLine("[" + ($cells -join ",") + "],")
    }
    [void]$sb.AppendLine("],")
}
[void]$sb.AppendLine("};")

# --- splice --------------------------------------------------------------------------
# Windows PowerShell 5.1's Get-Content defaults to the ANSI codepage, which mangles the
# template's em dashes into mojibake. Read as UTF-8 explicitly.
$tpl     = [System.IO.File]::ReadAllText((Resolve-Path (Join-Path $PSScriptRoot "app.template.html")).Path, [System.Text.Encoding]::UTF8)
$sprites = [System.IO.File]::ReadAllText((Resolve-Path (Join-Path $PSScriptRoot "sprites.js")).Path, [System.Text.Encoding]::UTF8)

if ($tpl -notmatch '//__DATA__')    { throw "template is missing the //__DATA__ marker" }
if ($tpl -notmatch '//__SPRITES__') { throw "template is missing the //__SPRITES__ marker" }

$html = $tpl.Replace("//__SPRITES__", $sprites).Replace("//__DATA__", $sb.ToString())

if ($html -notmatch '<!--__PWA_HEAD__-->')     { throw "template is missing the <!--__PWA_HEAD__--> marker" }
if ($html -notmatch '<!--__MOVED_BANNER__-->') { throw "template is missing the <!--__MOVED_BANNER__--> marker" }

# Shown ONLY on the Claude Artifact - that's the copy prone to losing progress on iOS (runs in
# a cross-origin iframe, see the GitHub Pages comment further down). Points people at the
# GitHub Pages copy instead. The plain index.html and the Pages copy itself both have this
# stripped to nothing: index.html has no "better" version to point at, and Pages obviously
# shouldn't link to itself.
$PAGES_URL = "https://btroyer2011.github.io/DroidTycoonTracker/"
$MOVED_BANNER = @"
<div class="movedBanner">
  <div class="movedBannerRow">
    <span>This page has moved.</span>
    <a href="$PAGES_URL" target="_blank" rel="noopener">Open the new version &rarr;</a>
  </div>
  <p class="movedBannerSub">Scroll down to <b>Backup &amp; restore</b> and export your progress
    first, so you can import it at the new site.</p>
</div>
"@

# PWA installability tags - spliced in ONLY for the docs/ (GitHub Pages) build. The plain
# index.html and the Artifact copy stay marker-free: both are meant to be fully self-contained
# with no sibling files, and a manifest/icon reference would 404 there.
$PWA_HEAD = @'
<link rel="manifest" href="manifest.json">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Rebirth Tracker">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<link rel="icon" type="image/png" sizes="32x32" href="icon-32.png">
'@

$enc = New-Object System.Text.UTF8Encoding($false)

$htmlWithMarkers = $html   # keep the pre-strip copy around for the docs/ and artifact builds below
$plainHtml = $html.Replace("<!--__PWA_HEAD__-->", "").Replace("<!--__MOVED_BANNER__-->", "")
$out = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\index.html"))
[System.IO.File]::WriteAllText($out, $plainHtml, $enc)

$mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
$tiles = ([regex]::Matches($sprites, 'data:image/jpeg;base64,')).Count
Write-Output "wrote index.html  ($mb MB, $tiles sprite tiles, 4 cycles x 30 rebirths)"

# --- artifact variant -----------------------------------------------------------------
# Published Artifacts supply their own <!doctype>/<html>/<head>/<body> skeleton, so this
# copy is page *content* only: <title>, the <style> block, then everything inside <body>.
# Extracted from $htmlWithMarkers (not the already-stripped $plainHtml) so the moved-banner
# marker inside <body> is still there to fill in below. The PWA_HEAD marker sits in <head>,
# outside both of these extractions, so it never needs stripping here.
$style = [regex]::Match($htmlWithMarkers, '(?s)<style>.*?</style>').Value
$body  = [regex]::Match($htmlWithMarkers, '(?s)<body>(.*)</body>').Groups[1].Value
if (-not $style) { throw "could not extract the <style> block" }
if (-not $body)  { throw "could not extract the <body> contents" }

$art = "<title>Super Rebirth Tracker - Droid Tycoon</title>`r`n" + $style + $body
$art = $art.Replace("<!--__MOVED_BANNER__-->", $MOVED_BANNER)
# note the [\s>] guard: <header> legitimately starts with "<head"
foreach ($bad in '<!doctype', '<html[\s>]', '<head[\s>]', '<body[\s>]', '</html>', '</head>', '</body>') {
    if ($art -match $bad) { throw "artifact copy still contains a wrapper tag matching $bad" }
}

$artOut = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "artifact.html"))
[System.IO.File]::WriteAllText($artOut, $art, $enc)
Write-Output ("wrote build\artifact.html  ({0} MB, wrapper-free copy for publishing)" -f `
              [math]::Round((Get-Item $artOut).Length / 1MB, 2))

# --- GitHub Pages / installable-web-app variant ----------------------------------------
# A real first-party https:// origin, unlike the Claude Artifact iframe, plus manifest +
# Apple meta tags so "Add to Home Screen" launches standalone. That combination is what gets
# iOS to treat this as a home-screen web app instead of a regular Safari tab, which is the
# documented way to escape Safari's 7-day storage-eviction timer for infrequently-opened sites.
$pwaHtml = $htmlWithMarkers.Replace("<!--__PWA_HEAD__-->", $PWA_HEAD).Replace("<!--__MOVED_BANNER__-->", "")
$docsDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\docs"))
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $docsDir "index.html"), $pwaHtml, $enc)

$manifest = @'
{
  "name": "Super Rebirth Tracker - Droid Tycoon",
  "short_name": "Rebirth Tracker",
  "description": "Track your Super Rebirth progress across all four Droid Tycoon cycles.",
  "start_url": "./index.html",
  "scope": "./",
  "display": "standalone",
  "background_color": "#07070a",
  "theme_color": "#07070a",
  "icons": [
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any" },
    { "src": "icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "maskable" },
    { "src": "icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
'@
[System.IO.File]::WriteAllText((Join-Path $docsDir "manifest.json"), $manifest, $enc)

$pwaMb = [math]::Round(((Get-Item (Join-Path $docsDir "index.html")).Length) / 1MB, 2)
Write-Output "wrote docs\index.html + manifest.json  ($pwaMb MB, for GitHub Pages)"
if (-not (Test-Path (Join-Path $docsDir "icon-192.png"))) {
    Write-Output "NOTE: docs\icon-*.png not found - run build\make-icons.ps1 once"
}
