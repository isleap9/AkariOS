namespace AkariOS.Core.Pipeline;

/// <summary>Named stages of the ISO injection pipeline, in execution order.</summary>
public enum BuildStage
{
    Validating,
    Mounting,
    Staging,
    Injecting,
    Rebuilding,
    Cleanup,
    Done,
}

/// <summary>A single progress update emitted by the pipeline.</summary>
public sealed record ProgressReport(
    BuildStage Stage,
    int? Percent,
    string Message,
    ProgressSeverity Severity = ProgressSeverity.Info);

public enum ProgressSeverity
{
    Info,
    Warning,
    Error,
}

/// <summary>Options controlling one injection build.</summary>
public sealed record InjectionOptions
{
    /// <summary>Path to the source Windows ISO.</summary>
    public required string SourceIsoPath { get; init; }

    /// <summary>Path of the output AkariOS ISO to write. Defaults next to the source when null.</summary>
    public string? OutputIsoPath { get; init; }

    /// <summary>Working directory for staging; defaults to a temp dir when null.</summary>
    public string? WorkingDirectory { get; init; }

    /// <summary>Payload files to inject into sources\$OEM$\$$\Setup\Scripts\.</summary>
    public required IReadOnlyList<string> PayloadFiles { get; init; }
}

/// <summary>Result of a pipeline run.</summary>
public sealed record BuildResult(bool Success, string? OutputIsoPath, string? ErrorMessage);
