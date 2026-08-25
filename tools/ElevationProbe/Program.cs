using System.Security.Principal;
using AkariOS.Core.Inject;
using AkariOS.Core.Iso;
using AkariOS.Core.Pipeline;
using AkariOS.Core.Wim;

// Probe: does the AkariOS pipeline actually need administrator rights?
// Run this WITHOUT elevation. Each stage reports OK/FAIL independently so we learn
// exactly which (if any) step requires admin, instead of guessing.

var isAdmin = new WindowsPrincipal(WindowsIdentity.GetCurrent())
    .IsInRole(WindowsBuiltInRole.Administrator);
Console.WriteLine($"[probe] elevated = {isAdmin}");
if (isAdmin)
{
    Console.WriteLine("[probe] ERROR: run this UNELEVATED for the test to mean anything.");
    return 2;
}

var iso = args.Length > 0
    ? args[0]
    : @"C:\Users\isleap\Desktop\26200.9267.260810-2309.25H2_GE_RELEASE_SVC_PROD3_CLIENTPRO_OEMRET_X64FRE_EN-US.ISO";

var progress = new Progress<ProgressReport>(r => Console.WriteLine($"    .. {r.Message}"));
var failures = new List<string>();
void Check(string name, Action body)
{
    Console.Write($"[probe] {name}: ");
    try { body(); Console.WriteLine("OK"); }
    catch (Exception ex)
    {
        Console.WriteLine($"FAIL -> {ex.GetType().Name}: {ex.Message.Split('\n')[0]}");
        failures.Add(name);
    }
}

// ---- 1. Mount ----------------------------------------------------------------
var mount = new IsoMountService();
string? drive = null;
Check("Mount-DiskImage", () => { drive = mount.MountAsync(iso).GetAwaiter().GetResult(); });
if (drive is null) { Console.WriteLine("[probe] cannot continue without a mount"); return 1; }
Console.WriteLine($"    mounted at {drive}");

var staging = Path.Combine(Path.GetTempPath(), "AkariOS", "probe-" + Path.GetRandomFileName());
try
{
    // ---- 2. Stage (robocopy the full tree) -----------------------------------
    var ctx = new BuildContext { Log = l => Console.WriteLine($"    | {l}") };
    ctx.MountedDrive = drive;
    var options = new InjectionOptions
    {
        SourceIsoPath = iso,
        WorkingDirectory = staging,
        PayloadFiles = [Path.Combine(AppContext.BaseDirectory, "probe-payload.ps1")],
    };
    File.WriteAllText(options.PayloadFiles[0], "Write-Host 'probe'");

    Check("robocopy staging (full ISO, ~5GB)", () =>
        new StagingStep().ExecuteAsync(options, ctx, progress, default).GetAwaiter().GetResult());

    // ---- 3. $OEM$ injection --------------------------------------------------
    Check("$OEM$ payload write", () =>
        new OemInjectStep().ExecuteAsync(options, ctx, progress, default).GetAwaiter().GetResult());

    // ---- 4. WIM servicing (wimlib) ------------------------------------------
    var wim = new WimService();
    Check("wimlib ListImages", () =>
    {
        foreach (var img in wim.ListImages(ctx.StagingDirectory!))
            Console.WriteLine($"    idx {img.Index}: {img.Name}");
    });
    Check("wimlib InjectPayload + Overwrite (real 9.7GB WIM)", () =>
        wim.InjectPayload(ctx.StagingDirectory!, options.PayloadFiles, [1], progress));

    // ---- 5. oscdimg ISO rebuild ---------------------------------------------
    var outIso = Path.Combine(Path.GetTempPath(), "AkariOS", "probe-out.iso");
    Check("oscdimg rebuild bootable ISO", () =>
    {
        var svc = new OscdimgService();
        Console.WriteLine($"    using {svc.LocateOscdimg()}");
        svc.BuildIsoAsync(ctx.StagingDirectory!, outIso, default, l => Console.WriteLine($"    | {l}"))
           .GetAwaiter().GetResult();
        Console.WriteLine($"    produced {new FileInfo(outIso).Length / 1024 / 1024} MB");
    });
    try { File.Delete(outIso); } catch { }
}
finally
{
    Check("Dismount-DiskImage", () => mount.DismountAsync(iso).GetAwaiter().GetResult());
    try
    {
        new StagingCleanupStep().ExecuteAsync(
            new InjectionOptions { SourceIsoPath = iso, PayloadFiles = [] },
            new BuildContext { StagingDirectory = Path.Combine(staging, "staging") },
            progress, default).GetAwaiter().GetResult();
        if (Directory.Exists(staging)) Directory.Delete(staging, recursive: true);
    }
    catch (Exception ex) { Console.WriteLine($"[probe] staging cleanup: {ex.Message}"); }
}

Console.WriteLine();
Console.WriteLine(failures.Count == 0
    ? "[probe] RESULT: entire pipeline works WITHOUT admin -> elevation can be dropped."
    : $"[probe] RESULT: needs admin for -> {string.Join(", ", failures)}");
return failures.Count == 0 ? 0 : 1;
