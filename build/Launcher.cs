// AkariOS.exe: starts Akari.ps1 from the exe's own folder (an AkariOS install, e.g. C:\AkariOS), after ZOICWARE's
// launcher (https://github.com/zoicware/ZOICWARE, MIT, src\ZoicwareLauncher.cs). Launcher.manifest asks for
// administrator rights, so Akari.ps1 starts elevated and runs with -ExecutionPolicy Bypass: no execution policy
// changes, no "Run with PowerShell". The exe does not wait: it is not in use when Akari updates its own folder
// (the console stays open while PowerShell runs in it). The release workflow compiles it with the .NET Framework's
// csc.exe (.github/workflows/release.yml).
using System;
using System.Diagnostics;
using System.IO;

namespace AkariOS
{
    static class Launcher
    {
        static int Main()
        {
            string dir = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(dir, "Akari.ps1");
            if (!File.Exists(script))
            {
                Console.Error.WriteLine("AkariOS.exe: Akari.ps1 is missing next to it (" + dir + "). Download AkariOS again.");
                Console.Write("Press any key to close...");
                Console.ReadKey(true);
                return 1;
            }
            Unblock(dir);
            var psi = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + script + "\"",
                WorkingDirectory = dir,
                UseShellExecute = false
            };
            Process.Start(psi);
            return 0;
        }

        // removes the "downloaded from the internet" mark from every file (as Unblock-File does)
        static void Unblock(string dir)
        {
            try
            {
                foreach (string f in Directory.EnumerateFiles(dir, "*", SearchOption.AllDirectories))
                {
                    try { string ads = f + ":Zone.Identifier"; if (File.Exists(ads)) File.Delete(ads); } catch { }
                }
            }
            catch { }
        }
    }
}
