; Inno Setup Installer Script for AUXTracker (Flutter Windows App)

[Setup]
AppName=AuxTracker
AppVersion=1.0.5
AppPublisher=Diavox Network Inc.
AppCopyright=© 2025 Diavox Network Inc. Developed by Jhun Norman Alonzo
AppPublisherURL=https://www.diavox.net/
AppSupportURL=https://www.diavox.net/help/technical-support/
AppUpdatesURL=https://www.diavox.net/
DefaultDirName={autopf}\AuxTracker
DefaultGroupName=AuxTracker
OutputBaseFilename=auxtracker-setup
UninstallDisplayIcon={app}\auxtrack.exe
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; Icon shown in the installer and Start Menu
SetupIconFile=assets\images\icon.ico
InfoBeforeFile=infobeforefile.txt

AppMutex=AuxTrackerSingleInstanceMutex

[Files]
; Copy the compiled Flutter Windows build
Source: "build\windows\x64\runner\Release\*"; \
DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; Include Visual C++ Runtime DLLs
Source: "windows\runner\resources\vcruntime140.dll"; \
DestDir: "{app}"; Flags: ignoreversion
Source: "windows\runner\resources\vcruntime140_1.dll"; \
DestDir: "{app}"; Flags: ignoreversion
Source: "windows\runner\resources\msvcp140.dll"; \
DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\AuxTracker"; Filename: "{app}\auxtrack.exe"
Name: "{commondesktop}\AuxTracker"; Filename: "{app}\auxtrack.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:";

[Run]
Filename: "{app}\auxtrack.exe"; Description: "Launch AuxTracker"; Flags: nowait postinstall skipifsilent