# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Network Driver" (a web search for the board).
# Action: it opens a search; it changes nothing.
@{
    Id          = 'tools-network-driver'
    Name        = 'Network driver'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Searches the web for your motherboard''s network driver: keep it on a USB stick before a reinstall, as a fresh Windows may have none.'
    Apply       = {
        $board = Get-CimInstance -ClassName Win32_BaseBoard
        Write-Log "Motherboard: $($board.Manufacturer) $($board.Product)"
        Start-Process ('https://www.google.com/search?q=' + [uri]::EscapeDataString("$($board.Manufacturer) $($board.Product) network driver"))
    }
}
