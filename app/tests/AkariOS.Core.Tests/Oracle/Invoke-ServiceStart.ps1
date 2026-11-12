# The reference for the native ServiceStart: Core\System.ps1's Set-AkariServiceStart with $AkariServicesRoot pointed
# at -Root (the test key's HKLM\SYSTEM\CurrentControlSet\Services, HKCU:\Software\AkariTest\<guid>\...), so its
# Set-ItemProperty writes the test key; Invoke-AkariRegistryTrusted records its rows. -Refuse: names whose admin
# write is refused (Set-ItemProperty throws for them), so the TrustedInstaller fallback runs. Writes
# @{ Error; Trusted = @('path|name|value') } as JSON to -Out.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$StartType, [string]$Refuse = '')
$ErrorActionPreference = 'Stop'
if ($Root -notlike 'HKCU:\Software\AkariTest\*') { throw "not a test key: $Root" }
. (Join-Path $Src 'Core\System.ps1')
$AkariServicesRoot = $Root
$script:Trusted = [Collections.Generic.List[string]]::new()
$refused = @($Refuse.Split(';') | Where-Object { $_ })
function Invoke-AkariRegistryTrusted($Rows, $Mode) {
    foreach ($r in @($Rows)) { $script:Trusted.Add("$($r.Path.Substring($Root.Length).TrimStart('\'))|$($r.Name)|$($r.Value)") }
}
function Set-ItemProperty {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Name, $Value, [string]$Type)
    if ((Split-Path $LiteralPath -Leaf) -in $refused) { throw 'Access is denied' }
    Microsoft.PowerShell.Management\Set-ItemProperty -LiteralPath $LiteralPath -Name $Name -Value $Value -Type $Type
}
$err = ''
try { Set-AkariServiceStart $Name $StartType } catch { $err = $_.Exception.Message }
[IO.File]::WriteAllText($Out, (ConvertTo-Json @{ Error = $err; Trusted = @($script:Trusted) } -Compress), [Text.UTF8Encoding]::new($false))
