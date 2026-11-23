; The native app's installer (Inno Setup 6). Built by build\Native.ps1, which passes:
;   /DVersion=<$AkariVersion>  /DSource=<the published AkariOS-Native.exe>  /DRoot=<the repo root>
; Installs the single-file exe to Program Files\AkariOS with a Start menu shortcut (a desktop one if picked) and an
; uninstaller; the PowerShell app's C:\AkariOS install is a separate thing and is left alone.
; Updates: an installed copy (unins000.exe beside it, Updates.IsInstalled) downloads the release's
; AkariOS-Native-Setup.exe and runs it with Updater.SetupArgs (/VERYSILENT ... /RELAUNCH=1): the app is closed, the
; exe replaced, then opened again by the [Run] entry below.
; User data (%LOCALAPPDATA%\AkariOS.Native, %ProgramData%\AkariOS.Native, the shared presets) is kept on uninstall.

#ifndef Version
  #error Pass /DVersion=<version>
#endif
#ifndef Source
  #error Pass /DSource=<path to AkariOS-Native.exe>
#endif
#ifndef Root
  #define Root ".."
#endif

[Setup]
AppId={{0A7FCC6D-64EC-4705-8CD8-361EF14DE846}
AppName=AkariOS
AppVersion={#Version}
AppVerName=AkariOS {#Version}
AppPublisher=isleap9
AppPublisherURL=https://github.com/isleap9/AkariOS
AppSupportURL=https://github.com/isleap9/AkariOS/issues
AppUpdatesURL=https://github.com/isleap9/AkariOS/releases
DefaultDirName={autopf}\AkariOS
DefaultGroupName=AkariOS
DisableProgramGroupPage=yes
DisableDirPage=auto
LicenseFile={#Root}\LICENSE
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputBaseFilename=AkariOS-Native-Setup
SetupIconFile={#Root}\src\Assets\AkariLogo.ico
UninstallDisplayIcon={app}\AkariOS-Native.exe
UninstallDisplayName=AkariOS
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
; the updater checks the setup's ProductVersion against the release: "1.5.0", never "1.5.0.0"
VersionInfoVersion={#Version}
VersionInfoProductVersion={#Version}
VersionInfoProductTextVersion={#Version}
VersionInfoDescription=AkariOS Setup
VersionInfoProductName=AkariOS

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Source}"; DestDir: "{app}"; DestName: "AkariOS-Native.exe"; Flags: ignoreversion
Source: "{#Root}\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion
Source: "{#Root}\CREDITS.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\AkariOS"; Filename: "{app}\AkariOS-Native.exe"
Name: "{autodesktop}\AkariOS"; Filename: "{app}\AkariOS-Native.exe"; Tasks: desktopicon

[Run]
; runascurrentuser: AkariOS-Native.exe requires administrator (its manifest); a postinstall entry otherwise runs as the
; original, non-elevated user and Windows refuses it (CreateProcess code 740). The setup is elevated already: no prompt.
; a normal install: the last page's "Launch AkariOS" box
Filename: "{app}\AkariOS-Native.exe"; Description: "{cm:LaunchProgram,AkariOS}"; Flags: nowait postinstall skipifsilent runascurrentuser
; an update (the app ran the setup silently with /RELAUNCH=1): opened again
Filename: "{app}\AkariOS-Native.exe"; Flags: nowait runascurrentuser; Check: Relaunch

[UninstallDelete]
; the self-update's leftovers of a copy that was portable before
Type: files; Name: "{app}\AkariOS-Native.exe.old"
Type: files; Name: "{app}\AkariOS-Native.exe.new"

[Code]
function Relaunch: Boolean;
begin
  Result := WizardSilent and (ExpandConstant('{param:RELAUNCH|0}') = '1');
end;
