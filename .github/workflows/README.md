# Workflows セットアップガイド

## build-and-release-client.yml

Flutter クライアント (`app/`) を Android / Windows の両プラットフォーム向けにビルドし、

- **Android**: AAB を Google Play 内部テストトラックへアップロード
- **Windows**: Inno Setup インストーラー (`.exe`) を生成

する。`workflow_dispatch` で手動実行し、環境（`dev` / `prod`）を選択する。
両プラットフォームの成果物は GitHub Release にもアセットとして添付される。

ワークフロー全体の設計は [docs/client-release-workflow.md](../../docs/client-release-workflow.md)、
Inno Setup スクリプトの設計は [docs/inno-setup-installer.md](../../docs/inno-setup-installer.md) を参照。

### 実行前に必要な準備

#### 1. Android 署名キーストアの用意

キーストアがまだない場合は作成する。

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

> 作成したキーストアは厳重に保管すること。紛失すると同一パッケージ名での再アップロードが不可能になる。

キーストアを Base64 に変換する。

```bash
# WSL / Linux / macOS
base64 -w0 upload-keystore.jks
```

```powershell
# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
```

#### 2. リポジトリ Secret の登録

**Settings → Secrets and variables → Actions → Repository secrets** に登録する。

| Secret 名 | 値 |
|-----------|----|
| `ANDROID_KEYSTORE_BASE64` | 手順 1 で得た Base64 文字列 |
| `ANDROID_KEYSTORE_PASSWORD` | キーストアのパスワード |
| `ANDROID_KEY_PASSWORD` | キーのパスワード |
| `ANDROID_KEY_ALIAS` | キーのエイリアス（例: `upload`） |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play API サービスアカウントの JSON キー全文（後述） |

#### 3. Google Play API サービスアカウントの設定

**Google Cloud Console でサービスアカウントを作成する。**

1. [Google Cloud Console](https://console.cloud.google.com/) → **IAM と管理 → サービスアカウント** を開く
2. **サービスアカウントを作成** → 名前（例: `github-actions-play`）を入力して作成
3. 作成したサービスアカウントを選択し、**キー → 鍵を追加 → 新しい鍵を作成 → JSON** でキーファイルをダウンロード

**Google Play Console でアクセス権を付与する。**

1. [Google Play Console](https://play.google.com/console) → **ユーザーと権限 → 新しいユーザーを招待**
2. サービスアカウントのメールアドレスを入力
3. アプリ（`net.irumaru.taskmanager`）を選択し、以下の権限を付与:
   - リリースの作成・編集
   - 内部テストトラックへの公開

**ダウンロードした JSON ファイルの中身全文** を `PLAY_SERVICE_ACCOUNT_JSON` に登録する。

#### 4. Inno Setup AppId（GUID）の生成

Windows インストーラーの `AppId`（同一アプリ判定に使われる GUID）を **dev / prod それぞれで 1 つずつ** 生成する。

- 生成例:
  - [https://www.guidgen.com/](https://www.guidgen.com/) で生成
  - PowerShell: `[guid]::NewGuid().ToString('B').ToUpper()`
- 形式: `{12345678-1234-1234-1234-123456789ABC}`（波括弧込み）

> **AppId は一度決めたら絶対に変えない。** 変更するとインストール済みユーザーがアップグレードできなくなり、
> 手動アンインストールが必要になる。

生成した値は手順 5 の `INNO_APP_ID` に登録する。

#### 5. GitHub Environments の作成

**Settings → Environments** で `dev` と `prod` を作成し、それぞれに以下を登録する。

##### Environment Secrets

| Secret 名 | 値 |
|-----------|----|
| `API_BASE_URL` | 各環境の API ベース URL |
| `GOOGLE_OAUTH_CLIENT_ID` | 各環境の Google OAuth クライアント ID |
| `INNO_APP_ID` | 手順 4 で生成した GUID（環境ごとに別の値） |

##### Environment Variables

| Variable 名 | dev の例 | prod の例 |
|-------------|---------|----------|
| `INNO_APP_NAME` | `TaskManager (Dev)` | `TaskManager` |
| `INNO_INSTALL_DIR_NAME` | `TaskManagerDev` | `TaskManager` |
| `INNO_OUTPUT_BASENAME` | `task-manager-dev-setup` | `task-manager-setup` |

`prod` 環境には **Required reviewers**（手動承認）を設定することを推奨する。

#### 6. Google Play Console への初回手動アップロード

Play API はアプリが Play Console に存在しない状態では AAB を受け付けない。
**ワークフロー初回実行前に、内部テストトラックへ AAB を一度手動でアップロードする必要がある。**

```bash
cd app
flutter build appbundle --release
```

生成された `build/app/outputs/bundle/release/app-release.aab` を
Play Console → **内部テスト → 新しいリリースを作成** からアップロードする。

> この手順を省略すると `play_upload` ジョブが `package not found` 系エラーで失敗する。

#### 7. リポジトリ側のファイル準備

- `app/windows/installer/installer.iss` を作成（雛形は [docs/inno-setup-installer.md](../../docs/inno-setup-installer.md)）
- `app/.gitignore` に `dist/` を追加（インストーラー生成物の除外）

### 動作確認

全準備完了後、**Actions → build-and-release/client → Run workflow** を開き、
`environment: dev` で手動実行して動作を確認する。

### versionCode 採番ルール

`pubspec.yaml` の `version` は変更せず、CI 側で `--build-number` を上書きする。

```
versionCode = YY × 10,000,000 + MM × 100,000 + DD × 1,000 + N
```

- `YY` = 西暦下2桁、`MM` = 月、`DD` = 日、`N` = 同日内連番
- 例: `client-v2026.0426.1` → `260426001`
- Google Play 上限（2,100,000,000）以内で 99 年まで桁あふれなし

Windows 側は Inno Setup の `AppVersion` にタグ名 `client-vYYYY.MMDD.N` をそのまま入れる。
