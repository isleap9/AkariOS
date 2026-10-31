using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using AkariOS.App.Look;

namespace AkariOS.App.Tests;

/// <summary>The motion service (one class: Motion.On is shared, and xUnit runs classes in parallel).</summary>
public sealed class MotionTests
{
    [Theory]
    [InlineData(MotionKind.Fade, null, null, "Opacity 0>1")]
    [InlineData(MotionKind.Rise, null, null, "Opacity 0>1, Y 10>0")]
    [InlineData(MotionKind.Rise, -8.0, null, "Opacity 0>1, Y -8>0")]
    [InlineData(MotionKind.Pop, null, null, "Opacity 0>1, ScaleX 0.96>1, ScaleY 0.96>1")]
    [InlineData(MotionKind.Scale, 0.5, null, "ScaleX 0.5>1, ScaleY 0.5>1")]
    [InlineData(MotionKind.Slide, -24.0, null, "X -24>0")]
    [InlineData(MotionKind.SlideY, null, 6.0, "Y now>6")]
    [InlineData(MotionKind.Fill, 0.0, 0.4, "ScaleX 0>0.4")]
    [InlineData(MotionKind.Width, null, 80.0, "Width now>80")]
    public void Plans_as_Get_AkariMotionPlan(MotionKind kind, double? from, double? to, string plan) =>
        Assert.Equal(plan, string.Join(", ", Motion.Plan(kind, from, to).Select(s => $"{s.Property} {(s.From is { } f ? f.ToString(System.Globalization.CultureInfo.InvariantCulture) : "now")}>{s.To.ToString(System.Globalization.CultureInfo.InvariantCulture)}")));

    [Fact]
    public void Width_and_height_need_an_end() => Assert.Throws<ArgumentException>(() => Motion.Plan(MotionKind.Height));

    [Theory]
    [InlineData(0, 100, 0, 0)]
    [InlineData(0, 100, 1, 100)]
    [InlineData(0, 100, 0.5, 88)]
    [InlineData(0, 100, 2, 100)]
    [InlineData(40, 10, -1, 40)]
    public void Counts_ease_out(double from, double to, double t, double value) => Assert.Equal(value, Motion.CountValue(from, to, t));

    [Theory]
    [InlineData(0, -120, 1000, 3, 48)]
    [InlineData(100, 120, 1000, 3, 52)]
    [InlineData(990, -240, 1000, 3, 1000)]
    [InlineData(10, 120, 1000, 3, 0)]
    public void A_wheel_notch_moves_the_target(double target, int delta, double max, int lines, double next) =>
        Assert.Equal(next, Motion.ScrollTarget(target, delta, max, lines));

    [Fact]
    public void The_glide_closes_on_its_target()
    {
        var x = 0.0;
        for (var i = 0; i < 30 && x != 300; i++) x = Motion.ScrollStep(x, 300, 16);
        Assert.Equal(300, x);
        Assert.Equal(300, Motion.ScrollStep(299.7, 300, 1));
        Assert.True(Motion.ScrollStep(0, 300, 72) is > 180 and < 200);
    }

    [Fact]
    public void Works_with_motion_on_and_off() => LookTests.OnSta(() =>
    {
        // the tokens, as Motion.xaml gives them
        Motion.Initialize(true);
        Assert.Equal([120, 200, 280, 30], new[] { "Fast", "Base", "Slow", "Stagger" }.Select(s => Motion.Duration(s).TotalMilliseconds));
        Assert.IsType<System.Windows.Media.Animation.CubicEase>(Motion.Easing("Ease"));
        Assert.IsType<System.Windows.Media.Animation.BackEase>(Motion.Easing("Spring"));

        // on: the end value is set at once, the animation plays over it
        var card = new Border();
        Motion.Start(card, MotionKind.Pop, speed: "Slow");
        Assert.Equal(1, (double)card.GetAnimationBaseValue(UIElement.OpacityProperty));
        Assert.True(card.HasAnimatedProperties);
        var g = Assert.IsType<TransformGroup>(card.RenderTransform);
        Assert.Equal(new Point(0.5, 0.5), card.RenderTransformOrigin);
        Motion.Start(card, MotionKind.Slide, -20, speed: "Fast");
        Assert.Same(g, card.RenderTransform);
        Assert.Equal(0, (double)((TranslateTransform)g.Children[^1]).GetAnimationBaseValue(TranslateTransform.XProperty));

        // a transform the element had is kept inside the group
        var turned = new Border { RenderTransform = new RotateTransform(15), RenderTransformOrigin = new Point(0, 1) };
        Motion.Start(turned, MotionKind.Rise);
        var tg = (TransformGroup)turned.RenderTransform;
        Assert.Equal(3, tg.Children.Count);
        Assert.IsType<RotateTransform>(tg.Children[0]);
        Assert.Equal(new Point(0, 1), turned.RenderTransformOrigin);

        // off: every Duration 0 and the end values, nothing animated
        Motion.Initialize(false);
        Assert.Equal(TimeSpan.Zero, Motion.Duration("Slow"));
        var bar = new Border { Opacity = 0.3 };
        Motion.Start(bar, MotionKind.Fade);
        Assert.Equal(1, bar.Opacity);
        Assert.False(bar.HasAnimatedProperties);

        var shown = new Border { Visibility = Visibility.Collapsed };
        Motion.Show(shown);
        Assert.Equal(Visibility.Visible, shown.Visibility);
        Motion.Hide(shown);
        Assert.Equal(Visibility.Collapsed, shown.Visibility);

        var count = new TextBlock { Text = "12" };
        Motion.Count(count, 1234);
        Assert.Equal(1234.ToString("N0"), count.Text);

        var page = new Border();
        Motion.Entrance(page);
        Assert.Equal(1, page.Opacity);

        // on again: an entrance hides it until the page is built
        Motion.Initialize(true);
        var later = new Border();
        Motion.Entrance(later);
        Assert.Equal(0, later.Opacity);
    });

    [Fact]
    public void A_pill_needs_a_laid_out_target() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        var canvas = new Canvas();
        var pill = new Border();
        canvas.Children.Add(pill);
        Assert.False(Motion.MovePill(pill, null));
        Assert.Equal(Visibility.Hidden, pill.Visibility);
        Assert.False(Motion.MovePill(pill, new Button()));
    });
}
