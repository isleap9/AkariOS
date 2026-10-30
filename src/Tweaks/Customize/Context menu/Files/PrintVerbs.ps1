# context-remove-print's rows: ZOICWARE's print verbs, only those whose key this Windows has
function Get-AkariPrintVerbRows {
    $c = 'HKLM:\SOFTWARE\Classes'
    $verbs = 'AppX4ztfk9wxr86nxmzzq47px0nh0e58b8fw\Shell\Print', 'SystemFileAssociations\image\shell\print', 'batfile\shell\print',
        'cmdfile\shell\print', 'docxfile\shell\print', 'fonfile\shell\print', 'htmlfile\shell\print', 'inffile\shell\print',
        'inifile\shell\print', 'JSEFile\Shell\Print', 'otffile\shell\print', 'pfmfile\shell\print', 'regfile\shell\print',
        'rtffile\shell\print', 'ttcfile\shell\print', 'ttffile\shell\print', 'txtfile\shell\print', 'VBEFile\Shell\Print',
        'VBSFile\Shell\Print', 'WSFFile\Shell\Print'
    foreach ($v in $verbs) {
        if (Get-AkariRegKey "$c\$v") { @{ Path = "$c\$v"; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Value = ''; Default = $null } }
    }
}
