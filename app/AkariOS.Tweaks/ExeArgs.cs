namespace AkariOS.Tweaks;

/// <summary>Arguments as PowerShell 5.1 passes an array to a program (Invoke-AkariExe's &amp; $Path @Arguments): space
/// separated, one with a space (or empty) in double quotes.</summary>
internal static class ExeArgs
{
    public static string Join(params string[] arguments) =>
        string.Join(' ', arguments.Select(a => a.Length == 0 || a.Contains(' ') ? $"\"{a}\"" : a));
}
