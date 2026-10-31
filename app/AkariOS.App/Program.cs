using System.IO;
using System.Runtime.InteropServices;
using System.Windows;

namespace AkariOS.App;

public static partial class Program
{
    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AttachConsole(int processId);

    [STAThread]
    public static int Main(string[] args)
    {
        if (Cli.IsCli(args))
        {
            // a WinExe has no console: write to the one it was started from
            AttachConsole(-1);
            var output = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
            return Cli.Run(args, output);
        }

        var app = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
        foreach (var d in AkariXaml.SharedResources("Dark", AkariXaml.MotionOn()))
            app.Resources.MergedDictionaries.Add(d);
        return app.Run(new MainWindow());
    }
}
