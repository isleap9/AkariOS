namespace AkariOS.Tweaks.Tests;

public class ScaffoldTests
{
    [Fact]
    public void Tweaks_never_reference_WPF()
    {
        var refs = TweaksAssembly.Get().GetReferencedAssemblies().Select(a => a.Name ?? "");
        Assert.DoesNotContain(refs, n => n is "PresentationFramework" or "PresentationCore" or "WindowsBase");
    }
}
