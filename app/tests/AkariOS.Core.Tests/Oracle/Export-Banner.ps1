# The reference for the native Banner.Art: the PowerShell app's Get-AkariBannerArt (Core\Log.ps1) on src\Assets\ascii.txt.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Log.ps1')
$art = @(Get-AkariBannerArt (Join-Path $Src 'Assets\ascii.txt'))
[IO.File]::WriteAllText($Out, (ConvertTo-Json -Compress @{ Rows = $art }), [Text.UTF8Encoding]::new($false))
