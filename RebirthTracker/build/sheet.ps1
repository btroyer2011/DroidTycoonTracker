# sheet.ps1 - contact sheet straight from the generated sprites.js, bypassing any browser cache.
param([int]$Cols = 6, [int]$Take = 36, [int]$Skip = 0, [string]$Out = "sheet.png")

Add-Type -AssemblyName System.Drawing

$txt = Get-Content (Join-Path $PSScriptRoot "sprites.js") -Raw
$matches = [regex]::Matches($txt, '"([^"]+)":"data:image/jpeg;base64,([^"]+)"')
$sel = $matches | Select-Object -Skip $Skip -First $Take

$tw = 212; $th = 162; $lab = 22
$rows = [math]::Ceiling($sel.Count / $Cols)
$sheet = New-Object System.Drawing.Bitmap (($Cols * $tw), ($rows * ($th + $lab)))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(18,18,22))
$font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150,230,255))

$i = 0
foreach ($m in $sel) {
    $bytes = [Convert]::FromBase64String($m.Groups[2].Value)
    $ms = New-Object System.IO.MemoryStream (,$bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    $cx = ($i % $Cols) * $tw
    $cy = [math]::Floor($i / $Cols) * ($th + $lab)
    $g.DrawImage($img, $cx, $cy, $tw, $th)
    $g.DrawString($m.Groups[1].Value, $font, $brush, ($cx + 3), ($cy + $th + 3))
    $img.Dispose(); $ms.Dispose()
    $i++
}
$g.Dispose()
$sheet.Save((Join-Path $PSScriptRoot $Out), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
Write-Output "wrote $Out : $($sel.Count) tiles (skip $Skip)"
