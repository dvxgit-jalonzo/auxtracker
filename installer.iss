; Inno Setup Installer Script for AUXTracker (Flutter Windows App)

[Setup]
AppName=AuxTracker
AppVersion=1.0.0
AppPublisher=Diavox
DefaultDirName={autopf}\AuxTracker
DefaultGroupName=AUXTracker
OutputBaseFilename=AuxTracker-Installer
Compression=lzma
SolidCompression=yes

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
Filename: "{app}\auxtrack.exe"; Description: "Launch AUXTracker"; Flags: nowait postinstall skipifsilent
