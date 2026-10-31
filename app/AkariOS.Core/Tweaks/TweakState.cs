namespace AkariOS.Core.Tweaks;

/// <summary>What a Toggle's setting is on this machine (Glossary: State).</summary>
public enum TweakState
{
    /// <summary>Matches what Apply sets.</summary>
    Optimized,
    /// <summary>Matches stock Windows.</summary>
    Default,
    /// <summary>Readable, but neither.</summary>
    Custom,
    /// <summary>Can't be read.</summary>
    Unknown,
}

/// <summary>Apply = the Tweak's change; Revert = back to the Windows Default (Glossary).</summary>
public enum TweakMode { Apply, Revert }
