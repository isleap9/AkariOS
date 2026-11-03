namespace AkariOS.Core.Machine;

/// <summary>A file from the AkariOS-Files release (Save-AkariFile): tools not on winget, such as NVIDIA Profile
/// Inspector.</summary>
public interface IDownloads
{
    /// <summary>Downloads it to outFile (its folder made first); throws when it can't.</summary>
    void Save(string name, string outFile);
}

/// <summary>The real one: HTTPS from GitHub (guarded).</summary>
public sealed class AkariFiles : IDownloads
{
    /// <summary>$AkariFilesUrl in src/Core/AppSetup.ps1 (a test keeps them equal).</summary>
    public const string Url = "https://github.com/isleap9/AkariOS-Files/releases/download/Files";

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };

    public AkariFiles() => SystemGuard.Check("Downloads");

    public void Save(string name, string outFile)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(outFile)!);
        using var response = Http.GetAsync($"{Url}/{Uri.EscapeDataString(name)}", HttpCompletionOption.ResponseHeadersRead).GetAwaiter().GetResult();
        response.EnsureSuccessStatusCode();
        using var body = response.Content.ReadAsStream();
        using var file = File.Create(outFile);
        body.CopyTo(file);
    }
}
