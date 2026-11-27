using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.UI;

namespace AkariOS.App.Controls;

/// <summary>
/// The Akari bloom (the design's SVG, a 560 x 280 drawing: a soft glow in the top right corner and three ribbons) laid
/// out as the design does: scaled to cover a <see cref="Layout"/> box and anchored to its top right corner (SVG's
/// "xMaxYMin slice"), the rest cropped, and faded out downwards from <c>fadeFrom</c> (a share of the box's height) to
/// nothing at its bottom (the design's CSS mask). WinUI has no opacity mask, so the fade is made of horizontal bands:
/// each holds its own copy of the drawing, clipped to its strip, at that strip's opacity. Plain XAML, no composition.
/// The sway (<see cref="Sways"/>) moves the drawing inside the strips, which stay still on whole pixels: moving the
/// strips themselves let their edges shimmer as they crossed pixels. The drawing hangs <c>overscan</c> px past the box's
/// right edge and above its top, so the sway never shows an edge.
/// </summary>
internal sealed partial class RibbonArt : Grid
{
    private const double ArtWidth = 560;
    private const double ArtHeight = 280;

    private readonly double _fadeFrom;
    private readonly double _overscanX;
    private readonly double _overscanY;
    private readonly List<(Canvas Band, ScaleTransform Scale, TranslateTransform Shift)> _bands = [];
    private readonly List<TranslateTransform> _sways = [];

    /// <summary>Each strip's sway: a storyboard moves them all together (X towards the left, Y down, within the overscan).</summary>
    public IReadOnlyList<TranslateTransform> Sways => _sways;

    /// <param name="rgb">The ribbons' colour.</param>
    /// <param name="lightRgb">Their light end.</param>
    /// <param name="fadeFrom">Where the fade starts, as a share of the box's height (0.4 = the page's light, 0.2 = a card's).</param>
    /// <param name="fadeBands">How many strips the fade is made of.</param>
    /// <param name="overscanX">How far the drawing hangs past the box's right edge (the sway's room to the left).</param>
    /// <param name="overscanY">How far it hangs above the box's top (the sway's room downwards).</param>
    public RibbonArt(uint rgb, uint lightRgb, double fadeFrom, int fadeBands, double overscanX = 0, double overscanY = 0)
    {
        _fadeFrom = Math.Clamp(fadeFrom, 0, 1);
        _overscanX = Math.Max(0, overscanX);
        _overscanY = Math.Max(0, overscanY);
        IsHitTestVisible = false;
        HorizontalAlignment = HorizontalAlignment.Right;
        VerticalAlignment = VerticalAlignment.Top;
        // the strip above the fade, then the fade's strips; each a Canvas, which never clips or crops its drawing
        for (var i = 0; i <= Math.Max(1, fadeBands); i++)
        {
            var scale = new ScaleTransform();
            var shift = new TranslateTransform();
            var sway = new TranslateTransform();
            var art = Drawing(rgb, lightRgb);
            art.RenderTransform = new TransformGroup { Children = { scale, shift, sway } };
            _sways.Add(sway);
            var band = new Canvas { IsHitTestVisible = false };
            band.Children.Add(art);
            Children.Add(band);
            _bands.Add((band, scale, shift));
        }
    }

    /// <summary>The box: <paramref name="width"/> x <paramref name="height"/> px; the drawing covers it from its top right
    /// corner, faded out to its bottom.</summary>
    public void Layout(double width, double height)
    {
        if (width <= 0 || height <= 0) return;
        Width = width;
        Height = height;
        Clip = new RectangleGeometry { Rect = new Rect(0, 0, width, height) };
        // covers the box and its overscan, anchored right: what doesn't fit is cropped on the left and at the bottom
        var s = Math.Max((width + _overscanX) / ArtWidth, (height + _overscanY) / ArtHeight);
        var dx = width + _overscanX - ArtWidth * s;
        var dy = -_overscanY;
        // strip edges on whole device pixels: two clips meeting between pixels leave a faint line
        var px = XamlRoot?.RasterizationScale is > 0 and var rs ? rs : 1;
        double Snap(double v) => Math.Round(v * px) / px;
        var top = _fadeFrom * height;
        var fades = _bands.Count - 1;
        var step = (height - top) / fades;
        for (var i = 0; i < _bands.Count; i++)
        {
            var (band, scale, shift) = _bands[i];
            double y0, y1, opacity;
            if (i == 0)
            {
                (y0, y1, opacity) = (0, top, 1);
            }
            else
            {
                y0 = top + (i - 1) * step;
                y1 = i == fades ? height : top + i * step;
                opacity = 1 - (i - 0.5) / fades; // the strip's middle on the fade from 1 to 0
            }
            y0 = Snap(y0);
            y1 = i == fades ? height : Snap(y1);
            band.Clip = new RectangleGeometry { Rect = new Rect(0, y0, width, Math.Max(0, y1 - y0)) };
            band.Opacity = opacity;
            scale.ScaleX = s;
            scale.ScaleY = s;
            shift.X = dx;
            shift.Y = dy;
        }
    }

    private static Color Rgb(uint rgb, byte alpha = 255) =>
        ColorHelper.FromArgb(alpha, (byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb);

    // the design's SVG: the corner glow (a radial gradient at 78 % / 20 %, 60 % wide) and three ribbons, each fading in
    // from its bottom left end
    private static Canvas Drawing(uint rgb, uint lightRgb)
    {
        var canvas = new Canvas { Width = ArtWidth, Height = ArtHeight, IsHitTestVisible = false };
        var glow = new RadialGradientBrush
        {
            Center = new Point(0.78, 0.2),
            GradientOrigin = new Point(0.78, 0.2),
            RadiusX = 0.6,
            RadiusY = 0.6,
        };
        glow.GradientStops.Add(new GradientStop { Color = Rgb(rgb, 140), Offset = 0 });
        glow.GradientStops.Add(new GradientStop { Color = Rgb(rgb, 0), Offset = 1 });
        canvas.Children.Add(new Rectangle { Width = ArtWidth, Height = ArtHeight, Fill = glow });
        canvas.Children.Add(Ribbon(Gradient(new Point(0, 1), new Point(1, 0), (rgb, 0, 0), (rgb, 230, 0.55), (lightRgb, 255, 1)),
            new Point(150, 280), (250, 200, 330, 80, 560, 30), new Point(560, 110), (390, 130, 300, 210, 260, 280), 1));
        canvas.Children.Add(Ribbon(Gradient(new Point(0, 1), new Point(1, 0.2), (lightRgb, 0, 0), (lightRgb, 217, 0.7), (0xFFFFFF, 230, 1)),
            new Point(280, 280), (350, 215, 430, 160, 560, 140), new Point(560, 196), (470, 205, 410, 240, 380, 280), 0.75));
        canvas.Children.Add(Ribbon(Gradient(new Point(0, 0), new Point(1, 1), (rgb, 0, 0), (rgb, 179, 1)),
            new Point(200, 0), (310, 50, 440, 60, 560, 0), new Point(560, 34), (440, 92, 300, 80, 200, 0), 0.6));
        return canvas;
    }

    private static LinearGradientBrush Gradient(Point start, Point end, params (uint Rgb, byte Alpha, double Offset)[] stops)
    {
        var brush = new LinearGradientBrush { StartPoint = start, EndPoint = end };
        foreach (var (c, a, o) in stops) brush.GradientStops.Add(new GradientStop { Color = Rgb(c, a), Offset = o });
        return brush;
    }

    private static Microsoft.UI.Xaml.Shapes.Path Ribbon(Brush fill, Point start,
        (double X1, double Y1, double X2, double Y2, double X3, double Y3) outward, Point corner,
        (double X1, double Y1, double X2, double Y2, double X3, double Y3) back, double opacity)
    {
        var figure = new PathFigure { StartPoint = start, IsClosed = true, IsFilled = true };
        figure.Segments.Add(new BezierSegment { Point1 = new Point(outward.X1, outward.Y1), Point2 = new Point(outward.X2, outward.Y2), Point3 = new Point(outward.X3, outward.Y3) });
        figure.Segments.Add(new LineSegment { Point = corner });
        figure.Segments.Add(new BezierSegment { Point1 = new Point(back.X1, back.Y1), Point2 = new Point(back.X2, back.Y2), Point3 = new Point(back.X3, back.Y3) });
        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);
        return new Microsoft.UI.Xaml.Shapes.Path { Data = geometry, Fill = fill, Opacity = opacity };
    }
}
