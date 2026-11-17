# The reference for the native uninstall, update all and installed list (app/AkariOS.Core/Apps: Winget.Uninstall,
# UpgradeAll, List, InstalledIds; AppKinds.Uninstall, InstalledApps): Core\Winget.ps1's and Core\Runner.ps1's real
# functions with a recorder in place of Invoke-AkariWinget, so winget.exe is never reached. -Case: a JSON file
#   { Codes: { '<package id | upgrade | list>': code }, Lines: { '<same key>': [winget's lines] },
#     Apps: [{ Id; Name; Winget: [ids]; Source; RemoveWith; Detect: 'true' | 'false' | 'throw' | '' }],
#     Uninstall: [app ids], Upgrade: bool, Installed: bool, Find: { Lines: []; Ids: [] } }
# Writes @{ Calls; Log; Outcomes = @('<id>|<Outcome>|<Reboot>|<Message>'); Upgrade ('' = not asked, else the result or
# 'error: <message>'); Installed = @(ids); Found = @(ids) } as JSON to -Out.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Case)
$ErrorActionPreference = 'Stop'
foreach ($f in 'Registry', 'Loader', 'Winget', 'Runner') { . (Join-Path $Src "Core\$f.ps1") }
# kept in $script: under a name no Core function uses (a function's own $c would hide it from the recorder)
$script:WingetCase = Get-Content -LiteralPath $Case -Raw | ConvertFrom-Json
$c = $script:WingetCase
$script:WingetCalls = [Collections.Generic.List[string]]::new()
$script:LogLines = [Collections.Generic.List[string]]::new()
function Write-Log([string]$Message) { $script:LogLines.Add($Message) }
function Get-CaseValue($Object, [string]$Key) {
    if ($null -eq $Object) { return $null }
    $p = $Object.PSObject.Properties[$Key]
    if ($p) { $p.Value } else { $null }
}
function Invoke-AkariWinget([string[]]$Arguments) {
    $script:WingetCalls.Add(($Arguments -join ' '))
    if ($Arguments[0] -eq '--version') { return @{ Code = 0; Out = @('v1.9.0') } }
    $key = if ($Arguments[0] -eq 'uninstall') { $Arguments[2] } else { $Arguments[0] }
    $code = Get-CaseValue $script:WingetCase.Codes $key
    @{ Code = $(if ($null -ne $code) { [int]$code } else { 0 }); Out = @(Get-CaseValue $script:WingetCase.Lines $key | Where-Object { $null -ne $_ }) }
}

$apps = @($c.Apps | Where-Object { $_ } | ForEach-Object {
    $h = @{ Id = $_.Id; Name = $_.Name; Section = 'Apps'; Category = 'Install'; Kind = 'Action' }
    if (@($_.Winget).Count) { $h.Winget = [string[]]@($_.Winget) }
    if ($_.Source) { $h.WingetSource = $_.Source }
    if ($_.RemoveWith) { $h.RemoveWith = $_.RemoveWith }
    switch ($_.Detect) { 'true' { $h.Detect = { $true } } 'false' { $h.Detect = { $false } } 'throw' { $h.Detect = { throw 'no' } } }
    if (-not $h.Winget) { $h.Apply = { } }
    ConvertTo-AkariTweak $h 'x' $false
})

$outcomes = @(foreach ($id in @($c.Uninstall | Where-Object { $_ })) {
    $o = Uninstall-AkariApp ($apps | Where-Object { $_.Id -eq $id })
    "$($o.Id)|$($o.Outcome)|$($o.Reboot)|$($o.Message)"
})
$upgrade = ''
if ($c.Upgrade) { $upgrade = try { [string](Update-AkariWingetPackages) } catch { "error: $($_.Exception.Message)" } }
$installed = @(if ($c.Installed) { Get-AkariInstalledApps $apps })
$found = @(if ($c.Find) { Get-AkariInstalledIds ([string[]]@($c.Find.Lines)) ([string[]]@($c.Find.Ids)) })
$result = [ordered]@{ Calls = @($script:WingetCalls); Log = @($script:LogLines); Outcomes = $outcomes; Upgrade = $upgrade; Installed = $installed; Found = $found }
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
