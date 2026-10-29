# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Privacy deny camera". Its own Toggle:
# a webcam that apps can't use breaks calls and streaming.
@{
    Id          = 'privacy-camera-deny'
    Name        = 'Block apps from the camera'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Turns off camera access for every app (Settings > Privacy > Camera). Video calls, streaming and Windows Hello face sign-in stop working until you turn it back on.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
    )
}
