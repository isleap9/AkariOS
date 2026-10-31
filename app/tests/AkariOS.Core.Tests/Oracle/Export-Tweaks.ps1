# The reference for the native Loader (app/AkariOS.Core/Tweaks/Loader.cs): the PowerShell app's Loader
# (src\Core\Loader.ps1, Get-AkariTweaks) on src\Tweaks, written as JSON for LoaderOracleTests: every Tweak's fields
# the Loader sets (not its blocks), the Groups and the Problems. Like the Pester tests, it loads the tweak files
# (& <file> builds their hashtables); no block in them runs.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Loader.ps1')

$root = (Resolve-Path (Join-Path $Src 'Tweaks')).Path
function Get-Rel([string]$Path) { 'src/Tweaks/' + $Path.Substring($root.Length).TrimStart('\').Replace('\', '/') }
function Get-Text($v) { if ($null -eq $v) { $null } else { [string]$v } }

$r = Get-AkariTweaks $root
$tweaks = foreach ($t in $r.Tweaks) {
    [ordered]@{
        Id = $t.Id; Name = Get-Text $t.Name; Description = Get-Text $t.Description; Section = $t.Section; Category = $t.Category
        Kind = $t.Kind; Risk = [string]$t.Risk; Button = Get-Text $t.Button; Confirm = Get-Text $t.Confirm
        Reboot = $t.Reboot; SafeMode = $t.SafeMode; Restarts = $t.Restarts; Explorer = $t.Explorer; AkariOS = $t.AkariOS
        Guided = $t.Guided; Editable = $t.Editable; Keep = $t.Keep
        Requires = @($t.Requires | Where-Object { $_ } | ForEach-Object { [string]$_ })
        Winget = @($t.Winget | Where-Object { $_ } | ForEach-Object { [string]$_ })
        WingetSource = Get-Text $t.WingetSource; AppType = Get-Text $t.AppType; StoreId = Get-Text $t.StoreId
        Group = Get-Text $t.Group; Package = Get-Text $t.Package
        Rows = @($t.Registry).Where({ $null -ne $_ }).Count
        Choices = @($t.Choices).Where({ $null -ne $_ }).Count
        Source = Get-Rel $t.Source
    }
}
$groups = foreach ($g in $r.Groups) {
    [ordered]@{ Id = $g.Id; EntryKind = [string]$g.EntryKind; Rows = @($g.Entries).Count; KeepNames = @($g.KeepNames | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }); Source = Get-Rel $g.Source }
}
$problems = foreach ($p in $r.Problems) { [ordered]@{ File = Get-Rel $p.File; Level = $p.Level; Message = $p.Message } }
$json = ConvertTo-Json @{ Tweaks = @($tweaks); Groups = @($groups); Problems = @($problems) } -Depth 10 -Compress
[IO.File]::WriteAllText($Out, $json, [Text.UTF8Encoding]::new($false))
