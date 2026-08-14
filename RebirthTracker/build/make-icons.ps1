# make-icons.ps1 - generate the Home Screen / manifest icons for the GitHub Pages build.
# Draws a bold italic "R" in the app's rebirth-number green on its dark background - the same
# visual language as the big Rebirth level number in the app itself. Run once; regenerate only
# if the palette or mark changes (build-app.ps1 does not call this on every build).

Add-Type -AssemblyName System.Drawing

$BG     = [System.Drawing.Color]::FromArgb(255, 0x07, 0x07, 0x0a)   # --bg
$GREEN  = [System.Drawing.Color]::FromArgb(255, 0x3d, 0xff, 0x9a)   # --green
$outDir = Join-Path $PSScriptRoot "..\..\docs"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-Icon {
    param([int]$Size, [string]$Path, [double]$GlyphScale = 0.62)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $g.Clear($BG)

    # kept within a safe-zone circle so Android's maskable cropping never clips the glyph
    $fontSize = [int]($Size * $GlyphScale)
    $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic), [System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Object System.Drawing.SolidBrush($GREEN)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = [System.Drawing.StringAlignment]::Center
    $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center

    # nudge up slightly - italic bold glyphs optically sit low against their own bounding box
    $rect = New-Object System.Drawing.RectangleF(0, ([single](-$Size * 0.035)), $Size, $Size)
    $g.DrawString("R", $font, $brush, $rect, $fmt)

    $g.Dispose()
    $bmp.Save((Join-Path $PSScriptRoot "..\..\$Path"), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $Path (${Size}x${Size})"
}

New-Icon -Size 512 -Path "docs/icon-512.png"
New-Icon -Size 192 -Path "docs/icon-192.png"
New-Icon -Size 180 -Path "docs/icon-180.png"
New-Icon -Size 32  -Path "docs/icon-32.png"  -GlyphScale 0.66
