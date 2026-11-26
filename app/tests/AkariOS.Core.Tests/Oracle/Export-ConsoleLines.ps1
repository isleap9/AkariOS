# The reference for the native console's look (app/AkariOS.Core/Runs/ConsoleLines.cs): src\Core\Log.ps1's
# ConvertTo-AkariConsoleLine on the lines ConsoleLinesTests writes, each as "text|color" segments joined by tabs.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Log.ps1')

$all = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$result = @(foreach ($m in $all) { (@(ConvertTo-AkariConsoleLine "$m" '12:03:44') | ForEach-Object { "$($_.Text)|$($_.Color)" }) -join "`t" })
[IO.File]::WriteAllText($Out, (ConvertTo-Json @($result) -Compress), [Text.UTF8Encoding]::new($false))
