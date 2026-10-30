# Action: the old Snipping Tool comes back from its installer, not through an Akari Revert.
# Ported from FR33THY Ultimate "bloatware" (legacy apps).
@{
    Id          = 'remove-snipping-tool-legacy'
    Name        = 'Snipping Tool (Windows 10)'
    Section     = 'Apps'
    Category    = 'Remove'
    Kind        = 'Action'
    Button      = 'Remove'
    Risk        = 'Safe'
    Description = 'Windows 10''s old Snipping Tool. The Store Snipping Tool (Win + Shift + S) is in the Store apps list.'
    Detect      = { -not (Test-Path "$env:SystemRoot\System32\SnippingTool.exe") }
    Apply       = { Invoke-AkariSelfUninstall "$env:SystemRoot\System32\SnippingTool.exe" 'SnippingTool' }
}
