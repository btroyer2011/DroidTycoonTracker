# detect-grid.ps1 - find the exact cell rectangles on a poster.
#
# Every droid cell is drawn with a bright coloured frame. A column sitting on a cell's
# left/right frame is bright for essentially the whole height of the row, whereas art,
# text and the black gaps between cells are not. Same idea vertically. So we look for
# runs of columns/rows whose bright-fraction is near 1.

param([string]$Src = "..\..\Cycle 1.jpg")

. "$PSScriptRoot\ImgLib.ps1"

$img = New-Object ImgLib.Img ((Resolve-Path $Src).Path)
Write-Output "image: $($img.W) x $($img.H)   src: $Src"

Write-Output "`n--- vertical frame runs (band y=210..400, x 0..3650) ---"
$img.ColRuns(0, 3650, 210, 400, 55, 0.97, 3) -join "  "

Write-Output "`n--- horizontal frame runs (band x=300..450, y 100..2782) ---"
$img.RowRuns(100, 2782, 300, 450, 55, 0.97, 3) -join "  "

$img.Dispose()
