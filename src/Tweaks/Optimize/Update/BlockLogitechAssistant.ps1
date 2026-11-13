# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksLogiBlock".
# Everyone denied writing to the folder (Write, mask 278, on the folder alone); Revert lifts the deny and leaves the
# empty folder, as winutil's does.
@{
    Id          = 'update-block-logitech-assistant'
    Name        = 'Block the Logitech Download Assistant'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Windows Update keeps installing the Logi Download Assistant with Logitech drivers; its folder is emptied and locked so it can''t come back. Logitech devices keep working.'
    Detect      = {
        $r = Get-AkariDenyRule "$env:ProgramFiles\LogiDownloadAssistant"
        if (($r -band 278) -eq 278) { 'Optimized' } elseif ($r -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $p = "$env:ProgramFiles\LogiDownloadAssistant"
        Stop-Process -Name 'logi_download_assistant' -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -Force | Remove-Item -Recurse -Force }
        else { New-Item -Path $p -ItemType Directory -Force | Out-Null }
        Set-AkariDenyRule $p 278
    }
    Revert      = {
        $p = "$env:ProgramFiles\LogiDownloadAssistant"
        if (Test-Path -LiteralPath $p) { Set-AkariDenyRule $p 0 }
    }
}
