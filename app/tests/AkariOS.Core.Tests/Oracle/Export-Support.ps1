# The reference for the native support file's scrubbing (app/AkariOS.Core/Support/SupportFile.cs): src\Core\Support.ps1's
# ConvertTo-AkariSupportText on the cases SupportOracleTests writes ({ Text; Users; Computer }), written back as JSON.
param([Parameter(Mandatory)][string]$Src, [Parameter(Mandatory)][string]$Cases, [Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
. (Join-Path $Src 'Core\Support.ps1')

# 5.1's ConvertFrom-Json hands a top-level array on as one object: foreach goes through it
$all = [IO.File]::ReadAllText($Cases) | ConvertFrom-Json
$result = @(foreach ($c in $all) {
    ConvertTo-AkariSupportText "$($c.Text)" @($c.Users | ForEach-Object { "$_" }) "$($c.Computer)"
})
[IO.File]::WriteAllText($Out, (ConvertTo-Json @($result) -Compress), [Text.UTF8Encoding]::new($false))
