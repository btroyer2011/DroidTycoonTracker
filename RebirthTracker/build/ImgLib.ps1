# ImgLib.ps1 - dot-source this to get a fast image helper backed by LockBits.
# Provides [ImgLib.Img] with column/row "bright fraction" scans used for grid detection,
# plus a Crop helper used by the cell extractor.

Add-Type -AssemblyName System.Drawing

if (-not ("ImgLib.Img" -as [type])) {
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

namespace ImgLib {
  public class Img : IDisposable {
    public int W, H;
    byte[] buf;      // BGR, stride-packed
    int stride;
    Bitmap bmp;

    public Img(string path) {
      bmp = new Bitmap(path);
      W = bmp.Width; H = bmp.Height;
      var data = bmp.LockBits(new Rectangle(0,0,W,H), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
      stride = data.Stride;
      buf = new byte[stride * H];
      System.Runtime.InteropServices.Marshal.Copy(data.Scan0, buf, 0, buf.Length);
      bmp.UnlockBits(data);
    }

    public int Lum(int x, int y) {
      int i = y * stride + x * 3;
      return (buf[i] + buf[i+1] + buf[i+2]) / 3;   // B,G,R average
    }

    // fraction of pixels in the vertical span [y0,y1] at column x that exceed thr
    public double ColBright(int x, int y0, int y1, int thr) {
      int n = 0, hit = 0;
      for (int y = y0; y <= y1; y++) { n++; if (Lum(x,y) > thr) hit++; }
      return n == 0 ? 0 : (double)hit / n;
    }

    // fraction of pixels in the horizontal span [x0,x1] at row y that exceed thr
    public double RowBright(int y, int x0, int x1, int thr) {
      int n = 0, hit = 0;
      for (int x = x0; x <= x1; x++) { n++; if (Lum(x,y) > thr) hit++; }
      return n == 0 ? 0 : (double)hit / n;
    }

    // Contiguous runs of columns in [xFrom,xTo] whose bright-fraction over [y0,y1] >= frac.
    // Returned as "start-end" strings; these land on the cells' vertical frame bars.
    public string[] ColRuns(int xFrom, int xTo, int y0, int y1, int thr, double frac, int minLen) {
      var outp = new List<string>();
      int start = -1;
      for (int x = xFrom; x <= xTo; x++) {
        bool on = ColBright(x, y0, y1, thr) >= frac;
        if (on && start < 0) start = x;
        if (!on && start >= 0) { if (x - start >= minLen) outp.Add(start + "-" + (x-1)); start = -1; }
      }
      if (start >= 0 && xTo - start + 1 >= minLen) outp.Add(start + "-" + xTo);
      return outp.ToArray();
    }

    public string[] RowRuns(int yFrom, int yTo, int x0, int x1, int thr, double frac, int minLen) {
      var outp = new List<string>();
      int start = -1;
      for (int y = yFrom; y <= yTo; y++) {
        bool on = RowBright(y, x0, x1, thr) >= frac;
        if (on && start < 0) start = y;
        if (!on && start >= 0) { if (y - start >= minLen) outp.Add(start + "-" + (y-1)); start = -1; }
      }
      if (start >= 0 && yTo - start + 1 >= minLen) outp.Add(start + "-" + yTo);
      return outp.ToArray();
    }

    public void Crop(int x, int y, int w, int h, int outW, int outH, string outPath, long quality) {
      using (var dst = new Bitmap(outW, outH))
      using (var g = Graphics.FromImage(dst)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.DrawImage(bmp, new Rectangle(0,0,outW,outH), new Rectangle(x,y,w,h), GraphicsUnit.Pixel);
        if (outPath.ToLower().EndsWith(".png")) {
          dst.Save(outPath, ImageFormat.Png);
        } else {
          ImageCodecInfo enc = null;
          foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.FormatID == ImageFormat.Jpeg.Guid) enc = c;
          var ps = new EncoderParameters(1);
          ps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
          dst.Save(outPath, enc, ps);
        }
      }
    }

    // Crop a droid sprite: cell interior only, with the poster's own corner badges painted
    // out (top-left SELL banner, top-right max-quality icon) so one tile can be reused for
    // every occurrence of that droid+rarity regardless of which banner that row carried.
    public byte[] SpriteJpeg(int x, int y, int w, int h, int outW, int outH,
                             int maskTriLeg, int maskTRw, int maskTRh,
                             int maskBLw, int maskBLh, long quality) {
      using (var dst = new Bitmap(outW, outH))
      using (var g = Graphics.FromImage(dst)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.DrawImage(bmp, new Rectangle(0,0,outW,outH), new Rectangle(x,y,w,h), GraphicsUnit.Pixel);

        double sx = (double)outW / w, sy = (double)outH / h;
        using (var black = new SolidBrush(Color.Black)) {
          int leg = (int)Math.Round(maskTriLeg * sx);
          g.FillPolygon(black, new Point[] { new Point(0,0), new Point(leg,0), new Point(0,(int)Math.Round(maskTriLeg*sy)) });
          int mw = (int)Math.Round(maskTRw * sx), mh = (int)Math.Round(maskTRh * sy);
          g.FillRectangle(black, outW - mw, 0, mw, mh);
          // bottom-left: the droid-class chip the poster prints above the rarity label
          int bw = (int)Math.Round(maskBLw * sx), bh = (int)Math.Round(maskBLh * sy);
          if (bw > 0 && bh > 0) g.FillRectangle(black, 0, outH - bh, bw, bh);
        }

        ImageCodecInfo enc = null;
        foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.FormatID == ImageFormat.Jpeg.Guid) enc = c;
        var ps = new EncoderParameters(1);
        ps.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
        using (var ms = new System.IO.MemoryStream()) {
          dst.Save(ms, enc, ps);
          return ms.ToArray();
        }
      }
    }

    // Tile many crops of the same size into a single contact sheet, labelled by index.
    public void Montage(int[] xs, int[] ys, int cw, int ch, int cols, int cellW, int cellH, string outPath) {
      int rows = (xs.Length + cols - 1) / cols;
      using (var dst = new Bitmap(cols * cellW, rows * cellH))
      using (var g = Graphics.FromImage(dst)) {
        g.Clear(Color.FromArgb(20,20,20));
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        for (int i = 0; i < xs.Length; i++) {
          int cx = (i % cols) * cellW, cy = (i / cols) * cellH;
          g.DrawImage(bmp, new Rectangle(cx, cy, cellW, cellH), new Rectangle(xs[i], ys[i], cw, ch), GraphicsUnit.Pixel);
        }
        dst.Save(outPath, ImageFormat.Png);
      }
    }

    public void Dispose() { if (bmp != null) bmp.Dispose(); }
  }
}
'@
}
