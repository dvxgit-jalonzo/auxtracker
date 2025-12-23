; Inno Setup Installer Script for AUXTracker (Flutter Windows App)

[Setup]
AppName=AuxTracker
AppVersion=1.0.0
AppPublisher=Diavox Network Inc.
AppCopyright=© 2025 Diavox Network Inc. Developed by Jhun Norman Alonzo
AppPublisherURL=https://www.diavox.net/
AppSupportURL=https://www.diavox.net/help/technical-support/
AppUpdatesURL=https://www.diavox.net/
DefaultDirName={autopf}\AuxTracker
DefaultGroupName=AuxTracker
OutputBaseFilename=auxtracker-setup
Compression=lzma
SolidCompression=yes
InfoBeforeFile=infobeforefile.txt
UninstallDisplayIcon={app}\auxtrack.exe

; Icon shown in the installer and Start Menu
SetupIconFile=assets\images\icon.ico

[Files]
; Copy the compiled Flutter Windows build
Source: "build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\AuxTracker"; Filename: "{app}\auxtrack.exe"

; Desktop shortcut
Name: "{commondesktop}\AuxTracker"; Filename: "{app}\auxtrack.exe"; Tasks: desktopicon

[Tasks]
; Optional checkbox for desktop icon
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:";

[Run]
; Run app after install (optional)
Filename: "{app}\auxtrack.exe"; Description: "Launch AuxTracker"; Flags: nowait postinstall skipifsilent
