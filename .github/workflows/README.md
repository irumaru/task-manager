# Workflows セットアップガイド

## build-and-release-client.yml

Flutter Android クライアントをビルドし、Google Play 内部テストトラックへ自動アップロードするワークフロー。
`workflow_dispatch` で手動実行し、環境（`dev` / `prod`）を選択する。

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

#### 4. GitHub Environments の作成

**Settings → Environments** で `dev` と `prod` を作成し、それぞれに Environment Secret を登録する。

| Secret 名 | 値 |
|-----------|----|
| `API_BASE_URL` | 各環境の API ベース URL |
| `GOOGLE_OAUTH_CLIENT_ID` | 各環境の Android 用 Google OAuth クライアント ID |

`prod` 環境には **Required reviewers**（手動承認）を設定することを推奨する。

#### 5. Google Play Console への初回手動アップロード

Play API はアプリが Play Console に存在しない状態では AAB を受け付けない。
**ワークフロー初回実行前に、内部テストトラックへ AAB を一度手動でアップロードする必要がある。**

```bash
cd app
flutter build appbundle --release
```

生成された `build/app/outputs/bundle/release/app-release.aab` を
Play Console → **内部テスト → 新しいリリースを作成** からアップロードする。

> この手順を省略すると `play_upload` ジョブが `package not found` 系エラーで失敗する。

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
