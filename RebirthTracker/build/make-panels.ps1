# make-panels.ps1 - cut each poster into 6 reading panels of 5 levels x 3 droid cells.
# Cropped 1:1 so every rarity/name label stays crisp for transcription.

. "$PSScriptRoot\ImgLib.ps1"
. "$PSScriptRoot\grid.ps1"

$outDir = Join-Path $PSScriptRoot "panels"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

foreach ($cycle in 1..4) {
    $src = Join-Path $PSScriptRoot "..\..\Cycle $cycle.jpg"
    $img = New-Object ImgLib.Img ((Resolve-Path $src).Path)
    foreach ($first in 1,6,11,16,21,26) {
        $r = Get-PanelRect -FirstLevel $first
        $out = Join-Path $outDir ("c{0}_L{1:d2}-{2:d2}.png" -f $cycle, $first, ($first+4))
        $img.Crop($r.X, $r.Y, $r.W, $r.H, $r.W, $r.H, $out, 100)
        Write-Output ("c{0} L{1}-{2}  {3}x{4} @ ({5},{6})" -f $cycle, $first, ($first+4), $r.W, $r.H, $r.X, $r.Y)
    }
    $img.Dispose()
}
