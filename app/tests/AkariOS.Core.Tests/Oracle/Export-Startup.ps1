# The reference for the native startup apps' pure parts (app/AkariOS.Core/Machine/StartupItems.cs,
# app/AkariOS.Core/Tweaks/StartupLists.cs): src\Core\Startup.ps1's and src\UI\StartupPage.ps1's pure functions on the
# cases StartupTests writes, written back as JSON.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Startup.ps1')
. (Join-Path $Src 'UI\StartupPage.ps1')

$c = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$items = @(foreach ($i in $c.Items) {
    [pscustomobject]@{ Key = "$($i.Location)|$($i.Name)"; Name = "$($i.Name)"; Command = "$($i.Command)"; Location = "$($i.Location)"; Scope = "$($i.Scope)"
        Enabled = [bool]$i.Enabled; Publisher = "$($i.Publisher)" }
})
$result = [ordered]@{
    Approved = @(foreach ($a in $c.Approved) { (ConvertTo-AkariStartupApproved ([bool]$a.Enabled) ([datetime]::FromFileTimeUtc([long]$a.FileTime))) -join ',' })
    Enabled  = @(foreach ($b in $c.Bytes) { Test-AkariStartupApproved $(if ($null -eq $b.Value) { $null } else { [byte[]]@($b.Value | ForEach-Object { [byte]$_ }) }) })
    Program  = @(foreach ($p in $c.Commands) { Get-AkariStartupProgram "$p" })
    Views    = @(foreach ($v in $c.Views) {
        $view = @(Get-AkariStartupView $items "$($v.Filter)" "$($v.Query)")
        [ordered]@{ Keys = (@($view | ForEach-Object { $_.Key }) -join ','); Count = (Get-AkariStartupCountText $items $view) }
    })
}
[IO.File]::WriteAllText($Out, (ConvertTo-Json $result -Depth 6 -Compress), [Text.UTF8Encoding]::new($false))
