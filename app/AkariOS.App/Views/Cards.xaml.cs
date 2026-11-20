using Microsoft.UI.Xaml;

namespace AkariOS.App.Views;

/// <summary>The shared card styles and template (x:Bind in a ResourceDictionary needs a class behind it).</summary>
public sealed partial class Cards : ResourceDictionary
{
    public Cards() => InitializeComponent();
}
