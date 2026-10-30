# Runs the Pester suite. Usage: powershell -NoProfile -ExecutionPolicy Bypass -File Tests\Run.ps1
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Path $PSScriptRoot -EnableExit
