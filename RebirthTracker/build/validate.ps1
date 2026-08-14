# validate.ps1 - correctness gate for the transcribed poster data.
#
# The SELL banners on the posters are redundant with the droid line-ups, which makes them a
# free audit of the transcription. For a droid needed at level L, let L' be the next level
# above L in the same cycle where that droid appears:
#
#   no L'                     -> yellow  (done with it)
#   L < 21 and L' >= 21       -> red     (sellable now, needed again in the 21-30 block)
#   otherwise                 -> none    (keep it, needed again shortly)
#
# Any disagreement between the derived badge and the badge read off the poster means either
# the name or the banner was misread - so every mismatch gets re-checked against the image.

$ErrorActionPreference = "Stop"
$RARITIES = @("BASE","GOLD","DIAMOND","RAINBOW","BESKAR","GALACTIC")
$issues = 0
$cellCount = 0

foreach ($c in 1..4) {
    $data = Get-Content (Join-Path $PSScriptRoot "cycle$c.json") -Raw | ConvertFrom-Json
    $levels = $data.levels

    if ($levels.Count -ne 30) { Write-Output "cycle ${c}: expected 30 levels, got $($levels.Count)"; $issues++ }

    # index every appearance of each droid name
    $where = @{}
    for ($i = 0; $i -lt $levels.Count; $i++) {
        if ($levels[$i].Count -ne 3) { Write-Output "c$c L$($i+1): expected 3 droids, got $($levels[$i].Count)"; $issues++ }
        foreach ($d in $levels[$i]) {
            if (-not $where.ContainsKey($d.n)) { $where[$d.n] = New-Object System.Collections.Generic.List[int] }
            $where[$d.n].Add($i + 1)
        }
    }

    for ($i = 0; $i -lt $levels.Count; $i++) {
        $lv = $i + 1
        foreach ($d in $levels[$i]) {
            $cellCount++
            if ($RARITIES -notcontains $d.r) { Write-Output "c$c L${lv} $($d.n): bad rarity '$($d.r)'"; $issues++ }
            if (@("Y","R","-") -notcontains $d.b) { Write-Output "c$c L${lv} $($d.n): bad badge '$($d.b)'"; $issues++ }

            $next = $null
            foreach ($l in $where[$d.n]) { if ($l -gt $lv) { $next = $l; break } }

            if ($null -eq $next)                  { $expect = "Y" }
            elseif ($lv -lt 21 -and $next -ge 21) { $expect = "R" }
            else                                  { $expect = "-" }

            if ($expect -ne $d.b) {
                $nx = if ($null -eq $next) { "never" } else { "L$next" }
                Write-Output ("MISMATCH  c{0} L{1,2} {2,-14} {3,-8} poster='{4}' derived='{5}'  (next use: {6})" -f `
                              $c, $lv, $d.n, $d.r, $d.b, $expect, $nx)
                $issues++
            }
        }
    }
}

Write-Output ""
Write-Output "checked $cellCount cells across 4 cycles"
if ($issues -eq 0) { Write-Output "RESULT: clean - every poster banner matches the derived rule" }
else { Write-Output "RESULT: $issues issue(s) - re-check those cells against the poster" }
