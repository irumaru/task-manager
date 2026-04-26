# Inno Setup インストーラー設計

Flutter Windows ビルド (`flutter build windows --release`) の成果物を
[Inno Setup](https://jrsoftware.org/isinfo.php) で `.exe` インストーラーにパッケージするための設計。

## 配置

```
app/windows/installer/installer.iss   # Inno Setup スクリプト本体（コミット対象）
app/dist/                             # インストーラー出力先（gitignore 対象）
```

`app/.gitignore` に `dist/` を追加してコミットから除外する。

## 設計方針

| 項目 | 値 / 設計 |
|------|----------|
| インストール範囲 | ユーザー単位（管理者権限不要） |
| インストール先 | `%LocalAppData%\Programs\<InstallDirName>` |
| スタートメニューショートカット | 必須 |
| デスクトップショートカット | ユーザーが選択（チェックボックス、デフォルト OFF） |
| 言語 | 日本語 |
| アーキテクチャ | x64 |
| dev / prod 切替 | `iscc /D` で `AppId` / `AppName` / `InstallDirName` / `OutputBaseFilename` を注入 |
| コード署名 | なし（SmartScreen 警告あり配布） |

## dev / prod の値の対応表

| 項目 | dev | prod | 注入元 |
|------|-----|------|--------|
| `AppId` | dev 用 GUID | prod 用 GUID | Environment Secret `INNO_APP_ID` |
| `AppName` | `TaskManager (Dev)` | `TaskManager` | Environment Variable `INNO_APP_NAME` |
| `InstallDirName` | `TaskManagerDev` | `TaskManager` | Environment Variable `INNO_INSTALL_DIR_NAME` |
| `OutputBaseFilename` | `task-manager-dev-setup` | `task-manager-setup` | Environment Variable `INNO_OUTPUT_BASENAME` |
| `AppVersion` | `client-vYYYY.MMDD.N` | 同左 | `calc_tag` ジョブの `tagName` |

> `AppId` は **一度決めたら絶対に変えない**。変えるとアップグレードができなくなり、
> ユーザー側で手動アンインストールが必要になる。

## CI での呼び出し例

```powershell
iscc `
  /DAppId="${{ secrets.INNO_APP_ID }}" `
  /DAppName="${{ vars.INNO_APP_NAME }}" `
  /DInstallDirName="${{ vars.INNO_INSTALL_DIR_NAME }}" `
  /DAppVersion="${{ needs.calc_tag.outputs.tagName }}" `
  /DOutputBaseFilename="${{ vars.INNO_OUTPUT_BASENAME }}-${{ needs.calc_tag.outputs.tagName }}" `
  /DSourceDir="..\..\build\windows\x64\runner\Release" `
  /DOutputDir="..\..\dist" `
  app\windows\installer\installer.iss
```

`windows-latest` ランナーには Inno Setup 6 がプリインストール済み（`ISCC.exe` が PATH 上）。
万一 PATH 解決に失敗する場合は `choco install -y innosetup` で導入する保険ステップを置く。

## スクリプト雛形

`app/windows/installer/installer.iss`:

```ini
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
  #define OutputDir "..\..\dist"
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
```

## 将来の拡張: コード署名

[SignPath Foundation](https://signpath.io/foundation) や有料証明書を導入する場合、
以下のいずれかの方法で署名できる。`installer.iss` 自体の構造を変える必要はない。

### A. Inno Setup 内で署名
```ini
[Setup]
SignTool=signtool sign /f "$f" /p "$p" /tr http://timestamp.digicert.com /td sha256 /fd sha256 $f
```

### B. ビルド後に signtool で署名
```powershell
signtool sign /f cert.pfx /p $env:CERT_PASSWORD `
  /tr http://timestamp.digicert.com /td sha256 /fd sha256 `
  app\dist\task-manager-setup-*.exe
```

CI ステップとしては、`iscc` 直後に signtool を呼ぶ形が単純。
