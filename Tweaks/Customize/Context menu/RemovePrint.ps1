# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Print": ProgrammaticAccessOnly on each
# file type's print verb. Only verbs this Windows has are touched (writing one that is missing would make an empty verb),
# so blocks instead of Registry rows. Revert deletes the value.
@{
    Id          = 'context-remove-print'
    Name        = 'Remove Print from files'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking a picture, document, font or script no longer shows Print (apps can still print it).'
    Detect      = {
        . "$AkariTweakDir\Files\PrintVerbs.ps1"
        $rows = @(Get-AkariPrintVerbRows)
        if (-not $rows) { return 'Unknown' }
        Get-AkariRegistryState $rows
    }
    Apply       = { . "$AkariTweakDir\Files\PrintVerbs.ps1"; Invoke-AkariRegistry @(Get-AkariPrintVerbRows) Apply }
    Revert      = { . "$AkariTweakDir\Files\PrintVerbs.ps1"; Invoke-AkariRegistry @(Get-AkariPrintVerbRows) Revert }
}
