using System.Diagnostics;
using System.Security.Principal;

// LauncherSpike — Phase 0 final proof: AkariOS (unelevated) launches the unmodified
// AME CLI elevated, with the AkariOS V5 playbook, and the engine runs end-to-end.
//
// Usage:
//   LauncherSpike.exe <cliDir> <playbookDir> [options...]
//     cliDir      folder containing TrustedUninstaller.CLI.exe
//     playbookDir EXTRACTED playbook folder (with playbook.conf + Configuration\)
//     options     optional feature-option names to pass through

if (args.Length < 2)
{
    Console.WriteLine("usage: LauncherSpike <cliDir> <playbookDir> [options...]");
    return 2;
}

var cliDir = Path.GetFullPath(args[0]);
var playbookDir = Path.GetFullPath(args[1]);
var cliExe = Path.Combine(cliDir, "TrustedUninstaller.CLI.exe");

Console.WriteLine($"[spike] elevated (this process) : {new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator)}");
Console.WriteLine($"[spike] cli                     : {cliExe}");
Console.WriteLine($"[spike] playbook                : {playbookDir}");

if (!File.Exists(cliExe)) { Console.WriteLine("[spike] FATAL: CLI exe not found"); return 2; }
if (!File.Exists(Path.Combine(playbookDir, "playbook.conf")))
{ Console.WriteLine("[spike] FATAL: playbook.conf not found (extract the .apbx first)"); return 2; }

// Per their README: cwd is the CLI folder, arg[0] is the extracted playbook path.
var psi = new ProcessStartInfo
{
    FileName = cliExe,
    Arguments = $"\"{playbookDir}\"" + (args.Length > 2 ? " " + string.Join(" ", args.Skip(2)) : ""),
    WorkingDirectory = cliDir,
    UseShellExecute = true,     // required for Verb=runas
    Verb = "runas",             // single UAC prompt, here, at launch-of-engine only
    CreateNoWindow = false,     // console stays visible: DefenderToggled ReadKey must work
};

Console.WriteLine("[spike] launching CLI elevated (accept the UAC prompt)...");
try
{
    using var p = Process.Start(psi)!;
    await p.WaitForExitAsync();
    Console.WriteLine($"[spike] CLI exited with code {p.ExitCode}");
    return p.ExitCode;
}
catch (System.ComponentModel.Win32Exception ex) when (ex.NativeErrorCode == 1223)
{
    Console.WriteLine("[spike] UAC prompt declined by user (1223).");
    return 1;
}
