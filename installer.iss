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
UninstallDisplayIcon={app}\auxtrack.exe

; --- BEST COMPRESSION SETTINGS START ---
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
LZMADictionarySize=65536
LZMANumFastBytes=273
; --- BEST COMPRESSION SETTINGS END ---

; Icon shown in the installer and Start Menu
SetupIconFile=assets\images\icon.ico
InfoBeforeFile=infobeforefile.txt

[Files]
; Copy the compiled Flutter Windows build
; Added 'dontcopy' or 'nocompression' is NOT needed here as LZMA2 handles it better.
Source: "build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\AuxTracker"; Filename: "{app}\auxtrack.exe"
Name: "{commondesktop}\AuxTracker"; Filename: "{app}\auxtrack.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:";

[Run]
Filename: "{app}\auxtrack.exe"; Description: "Launch AuxTracker"; Flags: nowait postinstall skipifsilent