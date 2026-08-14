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

$enc = New-Object System.Text.UTF8Encoding($false)
$out = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\index.html"))
[System.IO.File]::WriteAllText($out, $html, $enc)

$mb = [math]::Round((Get-Item $out).Length / 1MB, 2)
$tiles = ([regex]::Matches($sprites, 'data:image/jpeg;base64,')).Count
Write-Output "wrote index.html  ($mb MB, $tiles sprite tiles, 4 cycles x 30 rebirths)"

# --- artifact variant -----------------------------------------------------------------
# Published Artifacts supply their own <!doctype>/<html>/<head>/<body> skeleton, so this
# copy is page *content* only: <title>, the <style> block, then everything inside <body>.
$style = [regex]::Match($html, '(?s)<style>.*?</style>').Value
$body  = [regex]::Match($html, '(?s)<body>(.*)</body>').Groups[1].Value
if (-not $style) { throw "could not extract the <style> block" }
if (-not $body)  { throw "could not extract the <body> contents" }

$art = "<title>Super Rebirth Tracker - Droid Tycoon</title>`r`n" + $style + $body
# note the [\s>] guard: <header> legitimately starts with "<head"
foreach ($bad in '<!doctype', '<html[\s>]', '<head[\s>]', '<body[\s>]', '</html>', '</head>', '</body>') {
    if ($art -match $bad) { throw "artifact copy still contains a wrapper tag matching $bad" }
}

$artOut = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "artifact.html"))
[System.IO.File]::WriteAllText($artOut, $art, $enc)
Write-Output ("wrote build\artifact.html  ({0} MB, wrapper-free copy for publishing)" -f `
              [math]::Round((Get-Item $artOut).Length / 1MB, 2))
