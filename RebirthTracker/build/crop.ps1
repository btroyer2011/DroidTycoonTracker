# crop.ps1 - generic crop utility used for grid calibration
# usage: powershell -File crop.ps1 -Src "..\..\Cycle 1.jpg" -X 0 -Y 0 -W 1200 -H 600 -Out out.png
param(
    [Parameter(Mandatory=$true)][string]$Src,
    [Parameter(Mandatory=$true)][int]$X,
    [Parameter(Mandatory=$true)][int]$Y,
    [Parameter(Mandatory=$true)][int]$W,
    [Parameter(Mandatory=$true)][int]$H,
    [Parameter(Mandatory=$true)][string]$Out,
    [int]$Grid = 0
)

Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Image]::FromFile((Resolve-Path $Src).Path)
$rect = New-Object System.Drawing.Rectangle($X, $Y, $W, $H)
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($img, (New-Object System.Drawing.Rectangle(0,0,$W,$H)), $rect, [System.Drawing.GraphicsUnit]::Pixel)

if ($Grid -gt 0) {
    $penMinor = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(180, 0, 255, 0)), 1
    $penMajor = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(220, 255, 0, 255)), 2
    $font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Yellow)
    for ($gx = 0; $gx -lt $W; $gx += $Grid) {
        $abs = $X + $gx
        $pen = if ($abs % ($Grid*5) -eq 0) { $penMajor } else { $penMinor }
        $g.DrawLine($pen, $gx, 0, $gx, $H)
        if ($abs % ($Grid*5) -eq 0) { $g.DrawString("$abs", $font, $brush, $gx+2, 2) }
    }
    for ($gy = 0; $gy -lt $H; $gy += $Grid) {
        $abs = $Y + $gy
        $pen = if ($abs % ($Grid*5) -eq 0) { $penMajor } else { $penMinor }
        $g.DrawLine($pen, 0, $gy, $W, $gy)
        if ($abs % ($Grid*5) -eq 0) { $g.DrawString("$abs", $font, $brush, 2, $gy+2) }
    }
}

$g.Dispose()
$bmp.Save((Join-Path (Get-Location) $Out), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$img.Dispose()
Write-Output "wrote $Out ($W x $H) from ($X,$Y)"
