# grid.ps1 - poster geometry, measured by detect-grid.ps1 and identical (within 2px)
# across Cycle 1..4. Dot-source for the cell-rect helpers.
#
# Layout: 3 blocks of 10 rows (levels 1-10, 11-20, 21-30), each row 3 droid cells.

$script:BLOCK_X0    = 254.0    # left edge of block 0, slot 0
$script:BLOCK_PITCH = 1186.5   # x distance between blocks
$script:SLOT_PITCH  = 238.0    # x distance between droid cells inside a block
$script:CELL_W      = 238
$script:ROW_Y0      = 177.0    # top edge of row 0
$script:ROW_PITCH   = 258.7
$script:CELL_H      = 259

# level 1..30 -> block 0..2 and row 0..9
function Get-CellRect {
    param([int]$Level, [int]$Slot)
    $block = [math]::Floor(($Level - 1) / 10)
    $row   = ($Level - 1) % 10
    [pscustomobject]@{
        X = [int][math]::Round($script:BLOCK_X0 + $block * $script:BLOCK_PITCH + $Slot * $script:SLOT_PITCH)
        Y = [int][math]::Round($script:ROW_Y0 + $row * $script:ROW_PITCH)
        W = $script:CELL_W
        H = $script:CELL_H
    }
}

# a reading panel: 5 consecutive levels x 3 slots, cropped at 1:1 so the text stays crisp
function Get-PanelRect {
    param([int]$FirstLevel)
    $block = [math]::Floor(($FirstLevel - 1) / 10)
    $row   = ($FirstLevel - 1) % 10
    [pscustomobject]@{
        X = [int][math]::Round($script:BLOCK_X0 + $block * $script:BLOCK_PITCH - 8)
        Y = [int][math]::Round($script:ROW_Y0 + $row * $script:ROW_PITCH - 6)
        W = [int]($script:SLOT_PITCH * 3 + 16)
        H = [int][math]::Round($script:ROW_PITCH * 5 + 12)
    }
}
