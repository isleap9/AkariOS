# Action: an installed app is removed with its own uninstaller; Akari has no Revert for it.
# From Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/applications.json "klite".
@{
    Id          = 'install-k-lite-codecs'
    Name        = 'K-Lite Codec Pack Standard'
    Section     = 'Apps'
    Category    = 'Install'
    AppType     = 'Media'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Caution'
    Description = 'Video codecs and MPC-HC. Takes over video file types.'
    Winget      = 'CodecGuide.K-LiteCodecPack.Standard'
}
