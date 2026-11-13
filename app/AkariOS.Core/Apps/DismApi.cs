using System.Runtime.InteropServices;

namespace AkariOS.Core.Apps;

/// <summary>
/// The real DISM (dismapi.dll, the API the DISM cmdlets use; guarded): an online session per call, closed after.
/// The structs are packed to 1 byte (dismapi.h): DismCapability / DismFeature = a name pointer and a state, 12 bytes;
/// the *Info structs start the same way.
/// </summary>
public sealed partial class DismApi : IDism
{
    private const string Online = "DISM_{53BFAE52-B167-4E2F-A258-0A37B57FF845}";
    private const int AlreadyInitialized = unchecked((int)0xC0040001);
    private static readonly object Gate = new();
    private static bool _initialized;

    public DismApi() => SystemGuard.Check("DISM");

    /// <summary>DismPackageFeatureState as Get-WindowsCapability names it.</summary>
    public static string CapabilityStateName(int state) => state switch
    {
        0 => "NotPresent", 1 => "UninstallPending", 2 => "Staged", 3 => "Removed", 4 => "Installed",
        5 => "InstallPending", 6 => "Superseded", 7 => "PartiallyInstalled", _ => state.ToString(),
    };

    /// <summary>DismPackageFeatureState as Get-WindowsOptionalFeature names it.</summary>
    public static string FeatureStateName(int state) => state switch
    {
        0 or 2 => "Disabled", 1 => "DisablePending", 3 => "DisabledWithPayloadRemoved", 4 => "Enabled",
        5 => "EnablePending", 6 => "Superseded", 7 => "PartiallyInstalled", _ => state.ToString(),
    };

    public IReadOnlyList<DismItem> Capabilities() => Session(s =>
    {
        Check(DismGetCapabilities(s, out var items, out var count));
        return Items(items, count, CapabilityStateName);
    });

    public IReadOnlyList<DismItem> Features() => Session(s =>
    {
        Check(DismGetFeatures(s, null, 0, out var items, out var count));
        return Items(items, count, FeatureStateName);
    });

    public string? CapabilityState(string name) => Session(s =>
        DismGetCapabilityInfo(s, name, out var info) < 0 ? null : InfoState(info, CapabilityStateName));

    public string? FeatureState(string name) => Session(s =>
        DismGetFeatureInfo(s, name, null, 0, out var info) < 0 ? null : InfoState(info, FeatureStateName));

    public void RemoveCapability(string name) => Session(s => Check(DismRemoveCapability(s, name, 0, 0, 0)));

    public void DisableFeature(string name) => Session(s => Check(DismDisableFeature(s, name, null, 0, 0, 0, 0)));

    // Enable-WindowsOptionalFeature -All -NoRestart [-Source -LimitAccess]
    public void EnableFeature(string name, string? source) => WithSource(source, (paths, count) =>
        Session(s => Check(DismEnableFeature(s, name, null, 0, source is null ? 0 : 1, paths, count, 1, 0, 0, 0))));

    public void AddCapability(string name) => WithSource(null, (paths, count) =>
        Session(s => Check(DismAddCapability(s, name, 0, paths, count, 0, 0, 0))));

    /// <summary>DISM's PCWSTR* SourcePaths: one native string, freed after.</summary>
    private static void WithSource(string? source, Action<nint[]?, uint> work)
    {
        if (source is null) { work(null, 0); return; }
        var p = Marshal.StringToHGlobalUni(source);
        try { work([p], 1); }
        finally { Marshal.FreeHGlobal(p); }
    }

    // DismDriverPackage, packed to 1 byte (x64): PublishedName 0, OriginalFileName 8, InBox 16, CatalogFile 20,
    // ClassName 28, ClassGuid 36, ClassDescription 44, BootCritical 52, DriverSignature 56, ProviderName 60,
    // Date (SYSTEMTIME) 68, MajorVersion 84, MinorVersion 88, Build 92, Revision 96: 100 bytes
    private const int DriverSize = 100;

    public IReadOnlyList<DriverPackage> Drivers() => Session(s =>
    {
        Check(DismGetDrivers(s, 0, out var items, out var count));
        try
        {
            var list = new List<DriverPackage>((int)count);
            for (var i = 0; i < count; i++)
            {
                var at = items + i * DriverSize;
                string Text(int offset) => Marshal.PtrToStringUni(Marshal.ReadIntPtr(at, offset)) ?? "";
                int Word(int offset) => (ushort)Marshal.ReadInt16(at, offset);
                var date = DateTime.MinValue;
                try { date = new DateTime(Word(68), Word(70), Word(74)); } catch (ArgumentOutOfRangeException) { }
                var version = $"{Marshal.ReadInt32(at, 84)}.{Marshal.ReadInt32(at, 88)}.{Marshal.ReadInt32(at, 92)}.{Marshal.ReadInt32(at, 96)}";
                list.Add(new DriverPackage(Text(0), Text(8), Text(60), Text(28), version, date));
            }
            return list;
        }
        finally { DismDelete(items); }
    });

    /// <summary>DISM's list of {name pointer, state, ...} structs (stride: DismFeature / DismCapability 12 bytes,
    /// DismPackage 32), freed after.</summary>
    internal static List<DismItem> Items(nint items, uint count, Func<int, string> state, int stride = 12)
    {
        try
        {
            var list = new List<DismItem>((int)count);
            for (var i = 0; i < count; i++)
            {
                var at = items + i * stride;
                list.Add(new DismItem(Marshal.PtrToStringUni(Marshal.ReadIntPtr(at)) ?? "", state(Marshal.ReadInt32(at, 8))));
            }
            return list;
        }
        finally { DismDelete(items); }
    }

    private static string InfoState(nint info, Func<int, string> state)
    {
        try { return state(Marshal.ReadInt32(info, 8)); }
        finally { DismDelete(info); }
    }

    private static T Session<T>(Func<uint, T> work) => Session(Online, work);

    private static void Session(Action<uint> work) => Session<object?>(s => { work(s); return null; });

    /// <summary>DISM initialized once per process, then <paramref name="work"/> under the lock (one DISM call at a
    /// time; the ISO Builder's mount and unmount too).</summary>
    internal static T Locked<T>(Func<T> work)
    {
        lock (Gate)
        {
            if (!_initialized)
            {
                var hr = DismInitialize(0, null, null);
                if (hr < 0 && hr != AlreadyInitialized) Check(hr);
                _initialized = true;
            }
            return work();
        }
    }

    /// <summary>A session on <paramref name="image"/> (a mounted image's folder; the running Windows by default).</summary>
    internal static T Session<T>(string image, Func<uint, T> work) => Locked(() =>
    {
        Check(DismOpenSession(image, null, null, out var session));
        try { return work(session); }
        finally { DismCloseSession(session); }
    });

    /// <summary>A failed HRESULT as DISM's own message (3010, a restart needed, is success).</summary>
    internal static int Check(int hr)
    {
        if (hr >= 0) return hr;
        string? text = null;
        if (DismGetLastErrorMessage(out var msg) >= 0 && msg != 0)
        {
            text = Marshal.PtrToStringUni(Marshal.ReadIntPtr(msg))?.Trim();
            DismDelete(msg);
        }
        throw new InvalidOperationException(string.IsNullOrEmpty(text) ? $"DISM failed (0x{hr:X8})" : $"{text} (0x{hr:X8})");
    }

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismInitialize(int logLevel, string? logFilePath, string? scratchDirectory);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismOpenSession(string imagePath, string? windowsDirectory, string? systemDrive, out uint session);

    [LibraryImport("dismapi.dll")]
    private static partial int DismCloseSession(uint session);

    [LibraryImport("dismapi.dll")]
    internal static partial int DismDelete(nint dismStructure);

    [LibraryImport("dismapi.dll")]
    private static partial int DismGetLastErrorMessage(out nint errorMessage);

    [LibraryImport("dismapi.dll")]
    internal static partial int DismGetCapabilities(uint session, out nint capability, out uint count);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismGetCapabilityInfo(uint session, string name, out nint info);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial int DismRemoveCapability(uint session, string name, nint cancelEvent, nint progress, nint userData);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial int DismGetFeatures(uint session, string? identifier, int packageIdentifier, out nint feature, out uint count);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismGetFeatureInfo(uint session, string featureName, string? identifier, int packageIdentifier, out nint info);

    [LibraryImport("dismapi.dll")]
    private static partial int DismGetDrivers(uint session, int allDrivers, out nint driverPackage, out uint count);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial int DismDisableFeature(uint session, string featureName, string? packageName, int removePayload, nint cancelEvent, nint progress, nint userData);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismEnableFeature(uint session, string featureName, string? identifier, int packageIdentifier, int limitAccess,
        nint[]? sourcePaths, uint sourcePathCount, int enableAll, nint cancelEvent, nint progress, nint userData);

    [LibraryImport("dismapi.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int DismAddCapability(uint session, string name, int limitAccess, nint[]? sourcePaths, uint sourcePathCount,
        nint cancelEvent, nint progress, nint userData);
}
