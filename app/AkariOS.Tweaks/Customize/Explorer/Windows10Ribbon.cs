using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Explorer;

/// <summary>src/Tweaks/Customize/Explorer/Windows10Ribbon.ps1: its Registry rows, built with a foreach over the two
/// CLSID keys ($c and $dll read from the file).</summary>
[TweakCode("explorer-windows10-ribbon")]
public sealed class Windows10Ribbon : ITweakCode
{
    public IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c)
    {
        var clsid = (string)FileData.Variable(tweak, c, "c")!;
        var dll = (string)FileData.Variable(tweak, c, "dll")!;
        var rows = new List<RegistryRow>();
        foreach (var (g, name) in new[] { ("{2aa9162e-c906-4dd9-ad0b-3d24a8eef5a0}", "CLSID_ItemsViewAdapter"), ("{6480100b-5a83-4d1e-9f69-8ae5a88e9a33}", "File Explorer Xaml Island View Adapter") })
        {
            rows.Add(FileData.Row($@"{clsid}\{g}", "(default)", "String", name));
            rows.Add(FileData.Row($@"{clsid}\{g}\InProcServer32", "(default)", "String", dll));
            rows.Add(FileData.Row($@"{clsid}\{g}\InProcServer32", "ThreadingModel", "String", "Apartment"));
            rows.Add(FileData.KeyRow($@"{clsid}\{g}"));
        }
        return rows;
    }
}
