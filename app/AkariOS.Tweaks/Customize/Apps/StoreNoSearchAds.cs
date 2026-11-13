using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/StoreNoSearchAds.ps1 (winutil W3): Everyone denied the data of the Store's search
/// database in the real user's Local AppData (mask 7); no database = Unknown, and Apply fails saying so.</summary>
[TweakCode("apps-store-no-search-ads")]
public sealed class StoreNoSearchAds : ITweakCode
{
    private const int Data = 7;

    private static string Db(TweakContext c) =>
        Path.Combine(FileData.UserFolder(c, "Local AppData"), @"Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db");

    private static IFileAcl Acl(TweakContext c) => FileData.Need(c.Services.Acl, "file permissions");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var db = Db(c);
        if (!File.Exists(db)) return TweakState.Unknown;
        var r = Acl(c).Denied(db);
        return (r & Data) == Data ? TweakState.Optimized : r == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var db = Db(c);
        if (!File.Exists(db)) throw new InvalidOperationException("Open the Microsoft Store once first: it has no search database yet.");
        Acl(c).SetDeny(db, Data);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var db = Db(c);
        if (File.Exists(db)) Acl(c).SetDeny(db, 0);
    }
}
