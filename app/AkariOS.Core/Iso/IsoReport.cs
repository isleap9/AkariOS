using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace AkariOS.Core.Iso;

/// <summary>An operation's state on the build page and in the report.</summary>
[JsonConverter(typeof(JsonStringEnumConverter<IsoOpState>))]
public enum IsoOpState { Running, Done, Skipped, Failed }

/// <summary>One operation of a build stage (an app, a feature, the files of a path, the .NET 3.5 payload…): reported
/// Running when it starts, then Done / Skipped / Failed with how long it took and why. <paramref name="Stage"/> = the
/// index of its step in <see cref="IsoPlan.Steps"/>.</summary>
public sealed record IsoOperation(int Stage, string Name, IsoOpState State, TimeSpan Elapsed, string Note = "");

/// <summary>A stage in the report: its step, how it ended, how long it took, its operations.</summary>
public sealed record IsoReportStage(string Id, string Text, string State, double Seconds, IReadOnlyList<IsoReportOperation> Operations);

public sealed record IsoReportOperation(string Name, IsoOpState State, double Seconds, string Note);

/// <summary>A build's report, written next to the ISO as &lt;name&gt;.report.json (after Tiny11 Builder's idea): what
/// was built from what, each stage and operation with its time, the ISO's size and SHA-256, or why it failed.</summary>
public sealed record IsoReport
{
    public string AkariOS { get; init; } = AkariInfo.Version;
    public DateTime Started { get; init; }
    public DateTime Finished { get; init; }
    public bool Ok { get; init; }
    public string Message { get; init; } = "";
    public string Source { get; init; } = "";
    public string Edition { get; init; } = "";
    public string Iso { get; init; } = "";
    public long Size { get; init; }
    public string Sha256 { get; init; } = "";
    public IReadOnlyList<IsoReportStage> Stages { get; init; } = [];

    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public string ToJson() => JsonSerializer.Serialize(this, Options);

    public static IsoReport? FromJson(string json) => JsonSerializer.Deserialize<IsoReport>(json, Options);

    /// <summary>The report's file for an ISO: Win11-Akari.iso → Win11-Akari.report.json.</summary>
    public static string FileFor(string iso) => Path.ChangeExtension(iso, ".report.json");

    /// <summary>A file's SHA-256 as lowercase hex ("" when it isn't there).</summary>
    public static string Sha256Of(string file)
    {
        if (!File.Exists(file)) return "";
        using var s = File.OpenRead(file);
        return Convert.ToHexStringLower(System.Security.Cryptography.SHA256.HashData(s));
    }
}
