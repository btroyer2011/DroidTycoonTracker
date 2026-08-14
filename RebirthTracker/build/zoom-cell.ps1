# zoom-cell.ps1 - blow up specific droid cells for verification.
# usage: .\zoom-cell.ps1 -Cycle 4 -Levels 12,13,14,15 -Slots 1,2,3

param(
    [int]$Cycle = 1,
    [int[]]$Levels = @(1),
    [int[]]$Slots = @(1,2,3),
    [int]$Scale = 2,
    [string]$Out = "zoom.png"
)

. "$PSScriptRoot\ImgLib.ps1"
. "$PSScriptRoot\grid.ps1"

$src = Join-Path $PSScriptRoot "..\..\Cycle $Cycle.jpg"
$img = New-Object ImgLib.Img ((Resolve-Path $src).Path)

$xs = New-Object System.Collections.Generic.List[int]
$ys = New-Object System.Collections.Generic.List[int]
foreach ($lv in $Levels) {
    foreach ($sl in $Slots) {
        $r = Get-CellRect -Level $lv -Slot ($sl - 1)
        $xs.Add($r.X); $ys.Add($r.Y)
    }
}

$outPath = Join-Path $PSScriptRoot $Out
$img.Montage($xs.ToArray(), $ys.ToArray(), $script:CELL_W, $script:CELL_H,
             $Slots.Count, ($script:CELL_W * $Scale), ($script:CELL_H * $Scale), $outPath)
$img.Dispose()
Write-Output "wrote $Out : cycle $Cycle levels $($Levels -join ',') slots $($Slots -join ',') at ${Scale}x"
