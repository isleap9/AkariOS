using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Controls;

/// <summary>
/// A page's banner (the Aurora banner, the design's page D): <see cref="Crumbs"/> (CrumbLinks, shown by Cards.xaml's
/// CrumbTemplate), <see cref="Title"/> in TitleLargeTextBlockStyle, one line of <see cref="Lead"/> text and the page's
/// main <see cref="Actions"/> on the right; under <see cref="NarrowWidth"/> the actions go under the text. About 150 px
/// tall, straight on the page's <see cref="AuroraBackdrop"/>.
/// </summary>
public sealed partial class PageBanner : UserControl
{
    public const double NarrowWidth = 640;

    public static readonly DependencyProperty TitleProperty = DependencyProperty.Register(
        nameof(Title), typeof(string), typeof(PageBanner), new PropertyMetadata("", (d, e) => ((PageBanner)d).TitleText.Text = e.NewValue as string ?? ""));

    public static readonly DependencyProperty LeadProperty = DependencyProperty.Register(
        nameof(Lead), typeof(string), typeof(PageBanner), new PropertyMetadata("", (d, e) => ((PageBanner)d).SetLead(e.NewValue as string)));

    public static readonly DependencyProperty CrumbsProperty = DependencyProperty.Register(
        nameof(Crumbs), typeof(object), typeof(PageBanner), new PropertyMetadata(null, (d, e) => ((PageBanner)d).CrumbList.ItemsSource = e.NewValue));

    public static readonly DependencyProperty ActionsProperty = DependencyProperty.Register(
        nameof(Actions), typeof(object), typeof(PageBanner), new PropertyMetadata(null, (d, e) => ((PageBanner)d).ActionsHost.Content = e.NewValue));

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public string Lead
    {
        get => (string)GetValue(LeadProperty);
        set => SetValue(LeadProperty, value);
    }

    /// <summary>The way here as links (a page's CrumbLinks); null or empty = none.</summary>
    public object? Crumbs
    {
        get => GetValue(CrumbsProperty);
        set => SetValue(CrumbsProperty, value);
    }

    /// <summary>The page's main actions (buttons), on the right.</summary>
    public object? Actions
    {
        get => GetValue(ActionsProperty);
        set => SetValue(ActionsProperty, value);
    }

    public PageBanner()
    {
        InitializeComponent();
        SetLead("");
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
    }

    private void SetLead(string? text)
    {
        LeadText.Text = text ?? "";
        LeadText.Visibility = string.IsNullOrEmpty(text) ? Visibility.Collapsed : Visibility.Visible;
    }

    // narrow: the actions under the text, on the left
    private void Layout(double width)
    {
        var narrow = width < NarrowWidth;
        Grid.SetColumn(ActionsHost, narrow ? 0 : 1);
        Grid.SetRow(ActionsHost, narrow ? 1 : 0);
        ActionsHost.HorizontalAlignment = narrow ? HorizontalAlignment.Left : HorizontalAlignment.Right;
    }
}
