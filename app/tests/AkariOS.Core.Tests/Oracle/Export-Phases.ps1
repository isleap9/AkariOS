# The reference for the native Phases (Runs in phases): the PowerShell app's real Start-AkariPhases and
# Split-AkariSafeModePhases (Core\Phases.ps1) and Invoke-AkariPrepare (Core\Runner.ps1), with recorders in place of
# everything that reaches the PC or the rest of the engine. PhasesOracleTests writes -Scenarios (a JSON array); each
# scenario runs once and its steps come back:
#   Safe (Test-AkariSafeMode), Tweaks (@{ Id; Kind; SafeMode; Restarts; Prepare; Requires }: a Requires is never met),
#   States (id -> Get-AkariState), Results (id -> @{ Kind; Reboot; Message }: what Invoke-AkariPlan says, else
#   Applied / Reverted), PrepareFails (ids whose Prepare throws), Run (@{ Name; Next; Phases; Outcomes }).
# Steps: "save <Next>", "next <Boot>" (Set-AkariNextBoot), "safeboot off|on" (Set-AkariSafeBoot), "restart <seconds>",
# "plan <id,id>", "prepare <id>", "clear", "log <line>" (Write-Log; Invoke-AkariPrepare's own lines left out),
# "file <line>" (Write-ErrLog; the real Write-AkariRunSummary writes through both). Nothing real runs.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Scenarios, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Runner.ps1')
. (Join-Path $Src 'Core\Phases.ps1')

$script:Steps = $null
function Add-Step([string]$s) { $script:Steps.Add($s) }

# recorders (defined after the dot-sourcing, so they win)
function Write-Log([string]$Message) {
    if ($Message -like 'Getting ready for Safe Mode*' -or $Message -like 'Failed: *') { return }
    Add-Step "log $Message"
}
function Write-ErrLog([string]$Message) { Add-Step "file $Message" }
function Test-AkariSafeMode { [bool]$script:Scenario.Safe }
function Save-AkariRun($Run) { Add-Step "save $($Run.Next)" }
function Clear-AkariRun { Add-Step 'clear' }
function Set-AkariNextBoot([string]$Boot, [string]$AkariPath) { Add-Step "next $Boot" }
function Set-AkariSafeBoot([bool]$On) { Add-Step "safeboot $(if ($On) { 'on' } else { 'off' })" }
function Restart-AkariPC([int]$Seconds = 5) { Add-Step "restart $Seconds" }
function Get-AkariState($Tweak) {
    $s = $script:Scenario.States.PSObject.Properties[$Tweak.Id]
    if ($s) { [string]$s.Value } else { 'Default' }
}
function Test-AkariRequirement($Tweak) { if ($Tweak.Requires) { "needs $($Tweak.Requires)" } }
function Invoke-AkariPlan([object[]]$Items, $Tweaks) {
    Add-Step "plan $((@($Items) | ForEach-Object { $_.Id }) -join ',')"
    foreach ($i in @($Items)) {
        $r = $script:Scenario.Results.PSObject.Properties[$i.Id]
        $kind = if ($r) { [string]$r.Value.Kind } elseif ($i.Mode -eq 'Revert') { 'Reverted' } else { 'Applied' }
        $reboot = if ($r) { [bool]$r.Value.Reboot } else { $false }
        $msg = if ($r -and $r.Value.Message) { [string]$r.Value.Message } else { '' }
        New-AkariOutcome $i.Id $i.Mode $kind $reboot $msg
    }
}
# a Prepare block is "prepare <id>", throwing for PrepareFails
function Invoke-AkariTweakBlock($Block, [string]$Mode) { & $Block }

$all = @(Get-Content -LiteralPath $Scenarios -Raw | ConvertFrom-Json | ForEach-Object { $_ })
$results = foreach ($sc in $all) {
    $script:Scenario = $sc
    $script:Steps = [System.Collections.Generic.List[string]]::new()
    $fails = @($sc.PrepareFails | Where-Object { $_ } | ForEach-Object { [string]$_ })
    $tweaks = @(foreach ($t in @($sc.Tweaks | Where-Object { $_ })) {
        $h = @{ Id = [string]$t.Id; Name = "$($t.Id) name"; Kind = [string]$t.Kind; SafeMode = [bool]$t.SafeMode; Restarts = [bool]$t.Restarts
            Requires = $(if ($t.Requires) { [string]$t.Requires } else { $null }) }
        if ($t.Prepare) {
            $id = [string]$t.Id
            $body = "Add-Step 'prepare $id'"
            if ($id -in $fails) { $body += "; throw 'no network for $id'" }
            $h.Prepare = [scriptblock]::Create($body)
        }
        $h
    })
    $phases = @(foreach ($p in @($sc.Run.Phases)) {
        $items = @(foreach ($i in @($p.Items | Where-Object { $_ })) { @{ Id = [string]$i.Id; Mode = [string]$i.Mode } })
        @{ Name = [string]$p.Name; Boot = [string]$p.Boot; Items = $items }
    })
    $outcomes = @($sc.Run.Outcomes | Where-Object { $_ } | ForEach-Object { New-AkariOutcome $_.Id $_.Mode $_.Outcome ([bool]$_.Reboot) ([string]$_.Message) })
    $run = @{ Name = [string]$sc.Run.Name; Sid = 'S-1-5-21-1'; Next = [int]$sc.Run.Next; Phases = $phases; Outcomes = $outcomes }
    $status = @(Start-AkariPhases $run $tweaks 'C:\Akari\Akari.ps1' | Where-Object { $_ -is [string] }) | Select-Object -Last 1
    [ordered]@{
        Status   = [string]$status
        Steps    = @($script:Steps)
        Next     = [int]$run.Next
        Phases   = @(foreach ($p in @($run.Phases)) {
                [ordered]@{ Name = [string]$p.Name; Boot = [string]$p.Boot; Items = @(@($p.Items) | Where-Object { $_ } | ForEach-Object { "$($_.Mode) $($_.Id)" }) }
            })
        Outcomes = @(@($run.Outcomes) | Where-Object { $_ } | ForEach-Object { "$($_.Outcome) $($_.Id) $($_.Mode) $([bool]$_.Reboot) $($_.Message)" })
    }
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json -Depth 8 -Compress @($results)), [Text.UTF8Encoding]::new($false))
