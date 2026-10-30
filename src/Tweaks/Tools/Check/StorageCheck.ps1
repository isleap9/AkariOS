# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Storage Check".
# Action: a check that reads free space and opens This PC; it changes nothing.
@{
    Id          = 'tools-storage-check'
    Name        = 'Storage check'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Shows each drive''s free space in the console and opens This PC. Keep SSDs at least 10% free; put Windows and games on an internal SSD, not a hard disk or external drive.'
    Apply       = {
        foreach ($v in @(Get-Volume | Where-Object { $_.DriveLetter -and $_.Size } | Sort-Object DriveLetter)) {
            Write-Log ('{0}: {1}% free ({2} of {3} GB)' -f $v.DriveLetter, [math]::Round($v.SizeRemaining / $v.Size * 100),
                [math]::Round($v.SizeRemaining / 1GB), [math]::Round($v.Size / 1GB))
        }
        Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:MyComputerFolder'
    }
}
