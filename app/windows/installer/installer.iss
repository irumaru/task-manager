; ---- パラメータ（CI から /D で上書き）----
#ifndef AppId
  #define AppId "{REPLACE-WITH-PROD-GUID}"
#endif
#ifndef AppName
  #define AppName "TaskManager"
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#ifndef InstallDirName
  #define InstallDirName "TaskManager"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "task-manager-setup"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\..\dist"
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=irumaru
DefaultDirName={localappdata}\Programs\{#InstallDirName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\task_manager.exe

[Languages]
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"

[Tasks]
Name: "desktopicon"; Description: "デスクトップにアイコンを作成する"; GroupDescription: "追加アイコン:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\task_manager.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\task_manager.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\task_manager.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
