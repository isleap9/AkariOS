using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;

// Phase 0 spike — can net10 actually drive the net472 AME engine in-process?
//
// We deliberately use reflection rather than a compile-time reference so the probe
// can report *how far* it gets instead of failing to build. Each step is reported
// independently, because the interesting result is the exact point of failure.

var engineDir = args.Length > 0
    ? args[0]
    : Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Temp", "amecli", "extracted");

Console.WriteLine($"[bridge] runtime      : {RuntimeInformation.FrameworkDescription}");
Console.WriteLine($"[bridge] engine dir   : {engineDir}");
Console.WriteLine();

var sharedPath = Path.Combine(engineDir, "TrustedUninstaller.Shared.dll");
if (!File.Exists(sharedPath))
{
    Console.WriteLine($"[bridge] FATAL: {sharedPath} not found");
    return 2;
}

// Resolve the engine's own dependencies out of its folder.
AppDomain.CurrentDomain.AssemblyResolve += (_, e) =>
{
    var name = new AssemblyName(e.Name).Name + ".dll";
    var candidate = Path.Combine(engineDir, name);
    return File.Exists(candidate) ? Assembly.LoadFrom(candidate) : null;
};

var results = new List<(string Step, bool Ok, string Detail)>();
void Step(string name, Func<string> body)
{
    try { results.Add((name, true, body())); }
    catch (Exception ex)
    {
        var inner = ex is TargetInvocationException { InnerException: { } i } ? i : ex;
        results.Add((name, false, $"{inner.GetType().Name}: {inner.Message.Split('\n')[0]}"));
    }
}

Assembly? shared = null;
Step("load TrustedUninstaller.Shared (net472 assembly)", () =>
{
    shared = Assembly.LoadFrom(sharedPath);
    return $"{shared.GetName().Name} v{shared.GetName().Version} (IL runtime {shared.ImageRuntimeVersion})";
});
if (shared is null) { Report(); return 1; }

Type? amel = null;
Step("resolve AmeliorationUtil type", () =>
{
    amel = shared.GetType("TrustedUninstaller.Shared.AmeliorationUtil", throwOnError: true);
    return amel!.FullName!;
});

Step("resolve RunPlaybook overloads", () =>
{
    var ms = amel!.GetMethods(BindingFlags.Public | BindingFlags.Static)
        .Where(m => m.Name == "RunPlaybook").ToList();
    return string.Join(", ", ms.Select(m => $"{m.GetParameters().Length} params"));
});

Step("resolve Interprocess.InterLink + progress types", () =>
{
    var il = shared.GetType("Interprocess.InterLink", throwOnError: true)!;
    var prog = shared.GetType("Interprocess.InterLink+InterProgress");
    var rep = shared.GetType("Interprocess.InterLink+InterMessageReporter");
    return $"InterLink OK; InterProgress={(prog is not null)}; InterMessageReporter={(rep is not null)}";
});

// The real question: does *executing* engine code work, or does it explode on a
// net472-only dependency (WPF/WinForms/COM/AppDomain APIs)?
Step("EXECUTE engine code: DeserializePlaybook on a missing path (expect a clean engine-level error)", () =>
{
    var m = amel!.GetMethod("DeserializePlaybook", BindingFlags.Public | BindingFlags.Static);
    if (m is null) return "method not found (signature differs)";
    try
    {
        m.Invoke(null, [Path.Combine(Path.GetTempPath(), "definitely-not-a-playbook")]);
        return "returned without throwing";
    }
    catch (TargetInvocationException tie)
    {
        // An engine-level exception means the assembly LOADED AND RAN under net10.
        var i = tie.InnerException!;
        if (i is FileNotFoundException or DirectoryNotFoundException or InvalidOperationException
            or NullReferenceException or ArgumentException)
            return $"engine code RAN (threw expected {i.GetType().Name}) -> execution works";
        throw;
    }
});

Step("EXECUTE engine code: touch a type that pulls WPF/WinForms (USB.HumanReadableDiskSize)", () =>
{
    var usb = shared.GetType("TrustedUninstaller.Shared.USB.USB");
    if (usb is null) return "USB type not present";
    var m = usb.GetMethod("HumanReadableDiskSize", BindingFlags.Public | BindingFlags.Static);
    if (m is null) return "HumanReadableDiskSize not found";
    var v = m.Invoke(null, [16_000_000_000L]);
    return $"returned \"{v}\" -> WPF/WinForms-dependent assembly executes fine";
});

Report();

var hardFail = results.Any(r => !r.Ok);
Console.WriteLine();
Console.WriteLine(hardFail
    ? "[bridge] VERDICT: in-process net10 -> net472 engine is NOT viable as-is; needs a net472 host + IPC."
    : "[bridge] VERDICT: net10 CAN load and execute the net472 engine in-process.");
Console.WriteLine("[bridge] NOTE: this says nothing about TrustedInstaller escalation, which is tested separately.");
return hardFail ? 1 : 0;

void Report()
{
    Console.WriteLine();
    foreach (var (step, ok, detail) in results)
        Console.WriteLine($"  [{(ok ? "OK  " : "FAIL")}] {step}\n         {detail}");
}
