# -- Embedded asset decoding (D-06) -------------------------------------------
# Compile.ps1 base64-embeds every file in assets/text/ and assigns it to
# $sync.assets.<BaseName>. This helper turns one of those blobs back into a real
# file on disk so a child powershell.exe can run it with -File.
#
# Pure by default: the asset map and the destination root are both injectable, so
# a test can decode an injected blob into a scratch directory without touching the
# live %SystemRoot%\Temp and without reading the real $sync.assets.
#
# D-06: the decoded bytes are the upstream WinSux file, verbatim. Nothing here
# rewrites, patches or normalises the engine.

# Asset key -> file name on disk. Compile.ps1 keys $sync.assets by $_.BaseName,
# so the key has no extension, but the RunOnce values WinSux stores name
# %SystemRoot%\Temp\stepone.ps1 and steptwo.ps1 imports reg.reg from that same
# directory. A key that already carries an extension is used verbatim.
$script:AkariOSAssetFileNames = @{
    winsux  = "winsux.ps1"
    stepone = "stepone.ps1"
    steptwo = "steptwo.ps1"
    reg     = "reg.reg"
}

function Get-AkariOSAssetFileName {
    <#
    .SYNOPSIS
        Maps an asset key to the file name it is written as on disk.
    .DESCRIPTION
        Pure lookup. Known keys come from the table above; an unknown key that
        already contains a dot is passed through, and anything else gets a .ps1
        suffix (every other engine asset is a PowerShell stage script).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Name)

    if ($script:AkariOSAssetFileNames.ContainsKey($Name)) {
        return $script:AkariOSAssetFileNames[$Name]
    }
    if ($Name.Contains(".")) { return $Name }
    return "$Name.ps1"
}

function Expand-AkariOSEngineAsset {
    <#
    .SYNOPSIS
        Decodes one embedded base64 asset to disk and returns the written path.
    .DESCRIPTION
        The destination file name is the BARE engine name (stepone.ps1, steptwo.ps1,
        reg.reg, winsux.ps1) with no prefix and no subdirectory, because the RunOnce
        values WinSux stores name $env:SystemRoot\Temp\<name> exactly. A prefix or a
        different directory would make those entries point at nothing.

        Writes UTF-8 with NO byte-order mark: the engine is launched via
        powershell.exe -File, and a BOM is harmless there, but the .reg file is fed
        to reg.exe and a BOM in a .reg changes its first line's meaning. Stripping a
        leading BOM from the decoded text keeps both cases safe.

        Never throws. A missing asset key reports through Set-Status and returns $null
        so the caller can surface a message instead of taking down the install.
    .PARAMETER Name
        The asset key with NO extension: "winsux", "stepone", "steptwo", "reg".
    .PARAMETER Assets
        The asset map to decode from. Defaults to the live $sync.assets.
    .PARAMETER DestinationRoot
        Directory the file is written into. Defaults to %SystemRoot%\Temp.
    .PARAMETER Overwrite
        Rewrite the file when it already exists. Without it, an existing file is
        left alone and its path is returned unchanged.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        $Assets,
        [string]$DestinationRoot = (Join-Path $env:SystemRoot "Temp"),
        [switch]$Overwrite
    )

    # Defaults call the real source; any supplied parameter short-circuits it.
    if (-not $PSBoundParameters.ContainsKey("Assets")) { $Assets = $sync.assets }

    $encoded = $null
    if ($Assets) { $encoded = $Assets.$Name }

    if ([string]::IsNullOrWhiteSpace([string]$encoded)) {
        if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
            Set-Status ("Embedded script not found: {0}" -f $Name) "#EF5350"
        }
        return $null
    }

    $path = Join-Path $DestinationRoot (Get-AkariOSAssetFileName -Name $Name)

    if ((Test-Path -LiteralPath $path) -and (-not $Overwrite)) {
        return $path
    }

    try {
        $text = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
        $text = $text.TrimStart([char]0xFEFF)

        if (-not (Test-Path -LiteralPath $DestinationRoot)) {
            New-Item -ItemType Directory -Path $DestinationRoot -Force -ErrorAction Stop | Out-Null
        }

        [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        if (Get-Command Write-AkariOSLog -ErrorAction SilentlyContinue) {
            Write-AkariOSLog -Level ERROR -Message ("Failed to decode engine asset '{0}': {1}" -f $Name, $_)
        }
        if (Get-Command Set-Status -ErrorAction SilentlyContinue) {
            Set-Status ("Embedded script could not be written: {0}" -f $Name) "#EF5350"
        }
        return $null
    }

    return $path
}