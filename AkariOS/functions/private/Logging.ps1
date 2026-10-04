# -- Logging (DIAG-01) ----------------------------------------------------------
# Everything AkariOS does is written to %ProgramData%\AkariOS\install.log with an
# ISO8601 timestamp on every line, so a failed install can be diagnosed after the
# fact. The log is deliberately chatty: it is the only artefact that survives the
# reboots.
#
# Path is injectable (-Path) so tests can write to a scratch directory instead of
# the real ProgramData location.

$script:AkariOSLogMaxBytes = 5MB
$script:AkariOSLogMaxFiles = 3

function Get-AkariOSLogPath {
    <#
    .SYNOPSIS
        Returns %ProgramData%\AkariOS\install.log (DIAG-01).
    .PARAMETER Directory
        Override the containing directory. Defaults to %ProgramData%\AkariOS.
    #>
    [CmdletBinding()]
    param([string]$Directory = (Join-Path $env:ProgramData "AkariOS"))

    return (Join-Path $Directory "install.log")
}

function Initialize-AkariOSLog {
    <#
    .SYNOPSIS
        Creates the log directory, rotates an oversized log, and writes the
        startup banner (DIAG-01).
    .PARAMETER Path
        Full log file path. Defaults to Get-AkariOSLogPath.
    .PARAMETER Banner
        Extra lines written under the banner, e.g. OS build and PowerShell version.
    #>
    [CmdletBinding()]
    param([string]$Path = (Get-AkariOSLogPath),
          [string[]]$Banner = @())

    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Rotation: keep the previous few files as install.log.1, .2, .3.
    if (Test-Path -LiteralPath $Path) {
        $size = (Get-Item -LiteralPath $Path).Length
        if ($size -ge $script:AkariOSLogMaxBytes) {
            # Shift .N-1 -> .N, oldest first, dropping the oldest.
            for ($i = $script:AkariOSLogMaxFiles - 1; $i -ge 1; $i--) {
                $from = if ($i -eq 1) { $Path } else { "$Path." + ($i - 1) }
                $to   = "$Path.$i"
                if (Test-Path -LiteralPath $from) {
                    if (Test-Path -LiteralPath $to) {
                        Remove-Item -LiteralPath $to -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -LiteralPath $from -Destination $to -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Write-AkariOSLog -Path $Path -Level INFO -Message "=== AkariOS Setup started ==="
    Write-AkariOSLog -Path $Path -Level INFO -Message ("PowerShell {0} on {1}" -f $PSVersionTable.PSVersion, [System.Environment]::OSVersion.VersionString)
    foreach ($line in $Banner) {
        if ($line) { Write-AkariOSLog -Path $Path -Level INFO -Message $line }
    }
    return $Path
}

function Write-AkariOSLog {
    <#
    .SYNOPSIS
        Appends one ISO8601-timestamped line to the log (DIAG-01).
    .DESCRIPTION
        Never throws: a logging failure must not take down an install that is
        otherwise progressing.
    .PARAMETER Level
        INFO, WARN or ERROR. Anything else is written verbatim.
    .PARAMETER Message
        The text. Newlines are flattened so one entry stays one line.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][AllowEmptyString()][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO",
        [string]$Path = (Get-AkariOSLogPath)
    )

    try {
        $stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK")
        $flat  = ($Message -replace "[\r\n]+", " ").Trim()
        $line  = "{0} [{1}] {2}" -f $stamp, $Level.PadRight(5), $flat

        $dir = Split-Path -Path $Path -Parent
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Add-Content -LiteralPath $Path -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Swallow: logging must never break the install.
    }
}

function Get-AkariOSLogTail {
    <#
    .SYNOPSIS
        Returns the last N log lines, newest last. Used by the home panel's LOG
        card and by error reporting.
    #>
    [CmdletBinding()]
    param([int]$Count = 20,
          [string]$Path = (Get-AkariOSLogPath))

    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    try {
        return @(Get-Content -LiteralPath $Path -Tail $Count -ErrorAction Stop)
    } catch {
        return @()
    }
}