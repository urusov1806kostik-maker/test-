; Inno Setup 6 — создаёт ECHO_Setup.exe с ярлыком на рабочем столе
#define AppName "E.C.H.O"
#define AppVersion "1.0.0"
[Setup]
AppId={{6E2C8B1A-4F7D-4C8E-9E61-EC0A55150001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=E.C.H.O
DefaultDirName={localappdata}\Programs\ECHO
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=ECHO_Setup
SetupIconFile=..\assets\echo.ico
UninstallDisplayIcon={app}\ECHO.exe
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"
Name: "autostart"; Description: "Запускать E.C.H.O вместе с Windows"; GroupDescription: "Дополнительно:"; Flags: unchecked

[Files]
Source: "..\dist\ECHO\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\ECHO.exe"
Name: "{group}\Удалить {#AppName}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\ECHO.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "ECHO"; \
  ValueData: """{app}\ECHO.exe"" --minimized"; Tasks: autostart; Flags: uninsdeletevalue

[Run]
Filename: "{app}\ECHO.exe"; Description: "Запустить E.C.H.O"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/IM ECHO.exe /F"; Flags: runhidden; RunOnceId: "KillEcho"
