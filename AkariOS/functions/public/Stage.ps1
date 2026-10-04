# -- Stage explanations (SAFE-03) ----------------------------------------------
# The three stage descriptions are fixed by 01-UI-SPEC.md and must not be
# paraphrased. They live here as data so the progress panel can show the same
# wording the home panel uses, and so the stage runner can log them verbatim.

$script:AkariOSStages = @(
    [ordered]@{
        Number       = 1
        Key          = "stage1"
        Title        = "Prepare and reboot"
        Description  = "Stage 1: Downloads required payloads, configures boot settings, and reboots into Safe Mode."
        Cost         = "Cost: downloads several hundred MB and reboots the machine. You can cancel right up to the reboot."
        Reversible   = $true
        # Approximate share of the total progress bar once the stage completes.
        PercentStart = 0
        PercentEnd   = 20
    },
    [ordered]@{
        Number       = 2
        Key          = "stage2"
        Title        = "Safe Mode (console only)"
        Description  = "Stage 2: Runs in Safe Mode as TrustedInstaller. Disables Defender, modifies system protections, and reboots."
        Cost         = "Cost: permanently reduces your security posture. Run from a console window because the GUI does not render in Safe Mode. Cancel is no longer available."
        Reversible   = $false
        PercentStart = 20
        PercentEnd   = 60
    },
    [ordered]@{
        Number       = 3
        Key          = "stage3"
        Title        = "Tweaks and branding"
        Description  = "Stage 3: Removes bloatware, applies performance tweaks, sets AkariOS branding, and reboots to complete."
        Cost         = "Cost: removes applications and drivers that are not trivially reinstalled. A system restore point is the only reliable way back."
        Reversible   = $false
        PercentStart = 60
        PercentEnd   = 100
    }
)

function Get-AkariOSStage {
    <#
    .SYNOPSIS
        Returns the stage record for a stage number (1-3), or $null.
    #>
    [CmdletBinding()]
    param([int]$Number)
    return @($script:AkariOSStages | Where-Object { $_.Number -eq $Number })[0]
}

function Get-StageExplanation {
    <#
    .SYNOPSIS
        Returns the UI-SPEC explanation block for a stage: title, description,
        cost and reversibility (SAFE-03).
    .PARAMETER Number
        Stage number 1, 2 or 3.
    #>
    [CmdletBinding()]
    param([int]$Number)

    $stage = Get-AkariOSStage -Number $Number
    if (-not $stage) {
        return [pscustomobject]@{
            Number      = 0
            Title       = "Unknown stage"
            Description = ""
            Cost        = ""
            Reversible  = $false
        }
    }

    return [pscustomobject]@{
        Number      = $stage.Number
        Title       = $stage.Title
        Description = $stage.Description
        Cost        = $stage.Cost
        # SAFE-03: reversibility is stated, not implied.
        Reversible  = [bool]$stage.Reversible
        ReversibleText = if ($stage.Reversible) {
            "Reversible: you can cancel right up to the reboot into Safe Mode."
        } else {
            "Not easily reversible. Create a system restore point before continuing."
        }
    }
}