# Flutter クライアント リリース GitHub Actions 計画

Flutter クライアント (`app/`) を GitHub Actions でビルドし、

- **Android**: AAB を Google Play Console の内部テストトラックへ自動アップロード
- **Windows**: Inno Setup でインストーラー (`.exe`) を作成

の両方を 1 つのワークフローで matrix 並列実行する。
GitHub Release も併せて作成し、生成された AAB / インストーラーをアセットとして添付する。

## 方針

- 既存 [`.github/workflows/build-and-release-container.yml`](../.github/workflows/build-and-release-container.yml) を参考にする。
- 新規ファイル: `.github/workflows/build-and-release-client.yml`
- トリガー: `workflow_dispatch`（手動実行）
- 環境 (env): `dev` / `prod` を `workflow_dispatch.inputs.environment` で選択。
  - `API_BASE_URL`, `GOOGLE_OAUTH_CLIENT_ID` を環境ごとに Secrets で切り替える。
  - Inno Setup の `AppId` / 表示名 / インストール先も dev / prod で分離。
- 成果物:
  - **Android**: AAB（`flutter build appbundle --release`）
  - **Windows**: Inno Setup インストーラー `.exe`（`flutter build windows --release` → `iscc`）
- タグ命名: `client-vYYYY.MMDD.N`
  - 既存 container ワークフローの `vYYYY.MMDD.N` と分離。
  - `calc_tag` ジョブで `client-v` プレフィックス付きの最新番号を走査して採番。
- `pubspec.yaml` の `version` はリリース時に変更しない（手動運用のまま）。
- Windows はコード署名なし（SmartScreen 警告ありの公開）。将来 SignPath Foundation 等で
  署名を追加する際は、`build` ジョブの最後に署名ステップを差し込めるよう設計する。

## ジョブ構成

### 1. `calc_tag`
- `actions/github-script@v8` で `client-vYYYY.MMDD.N` の次番号を算出。
- 同時に `versionCode` も算出する（後述「versionCode 採番ルール」参照）。
- 出力: `tagName`, `versionCode`

### 2. `prepare`
- ビルド対象プラットフォームの matrix JSON を出力する。
- 値: `[{"platform":"android","runner":"ubuntu-latest"},{"platform":"windows","runner":"windows-latest"}]`
- 出力: `platforms`

### 3. `build`
依存: `calc_tag`, `prepare`
strategy: `matrix: { include: ${{ fromJson(needs.prepare.outputs.platforms) }} }`
runs-on: `${{ matrix.runner }}`

#### 共通ステップ
1. `actions/checkout@v6`
2. `subosito/flutter-action@v2`（channel: stable、`pubspec.yaml` の SDK 制約に合わせる）
3. `flutter pub get`（`working-directory: app`）

#### Android 固有ステップ（`if: matrix.platform == 'android'`）
1. `actions/setup-java@v4`（distribution: temurin, java-version: 17）
2. キーストア復元
   - `ANDROID_KEYSTORE_BASE64` を `base64 -d` して `app/android/app/upload-keystore.jks` に書き出す。
   - `app/android/key.properties` を生成:
     ```properties
     storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
     keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
     keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
     storeFile=upload-keystore.jks
     ```
   - `storeFile` は [`app/android/app/build.gradle.kts`](../app/android/app/build.gradle.kts) の `signingConfigs.release` が `file(...)` で解決するため、`app/` モジュール基準の相対パス（`upload-keystore.jks`）で OK。
3. AAB ビルド（`--build-number` で `versionCode` を上書き）:
   ```bash
   flutter build appbundle --release \
     --build-number=${{ needs.calc_tag.outputs.versionCode }} \
     --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
     --dart-define=GOOGLE_OAUTH_CLIENT_ID=${{ secrets.GOOGLE_OAUTH_CLIENT_ID }}
   ```
4. `actions/upload-artifact@v4` で `app/build/app/outputs/bundle/release/app-release.aab` をアップロード（artifact name: `android-aab`）。

#### Windows 固有ステップ（`if: matrix.platform == 'windows'`）
1. Windows ビルド:
   ```powershell
   flutter build windows --release `
     --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} `
     --dart-define=GOOGLE_OAUTH_CLIENT_ID=${{ secrets.GOOGLE_OAUTH_CLIENT_ID }}
   ```
   working-directory: `app`
2. Inno Setup でインストーラー生成:
   - `windows-latest` ランナーには Inno Setup 6 がプリインストール済み（`ISCC.exe` が PATH 上にある）。
   - 万一無い場合は `choco install -y innosetup` で導入する保険ステップを置く。
   - スクリプト: `app/windows/installer/installer.iss`（後述）
   - 実行例:
     ```powershell
     iscc `
       /DAppId="${{ secrets.INNO_APP_ID }}" `
       /DAppName="${{ vars.INNO_APP_NAME }}" `
       /DInstallDirName="${{ vars.INNO_INSTALL_DIR_NAME }}" `
       /DAppVersion="${{ needs.calc_tag.outputs.tagName }}" `
       /DOutputBaseFilename="${{ vars.INNO_OUTPUT_BASENAME }}-${{ needs.calc_tag.outputs.tagName }}" `
       /DSourceDir="..\..\build\windows\x64\runner\Release" `
       /DOutputDir="..\..\..\dist" `
       app\windows\installer\installer.iss
     ```
3. `actions/upload-artifact@v4` で `app/dist/*.exe` をアップロード（artifact name: `windows-installer`）。

### 4. `play_upload`
依存: `build`, `calc_tag`
条件: `if: always() && needs.build.result == 'success'`（Android のみ実行）

- `actions/download-artifact@v4` で `android-aab` を取得
- [`r0adkll/upload-google-play@v1`](https://github.com/r0adkll/upload-google-play) を使用
  ```yaml
  - uses: r0adkll/upload-google-play@v1
    with:
      serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
      packageName: net.irumaru.taskmanager
      releaseFiles: app-release.aab
      track: internal
      status: completed
      releaseName: ${{ needs.calc_tag.outputs.tagName }}
  ```
- Play Console 側で事前に以下が必要:
  - アプリ作成済み（`net.irumaru.taskmanager`）
  - 内部テストトラックの設定済み
  - Google Cloud のサービスアカウント発行 + Play Console から「ユーザーと権限」でアクセス権付与
  - 初回 AAB は手動でアップロードしないと API からアップロードできない（Play API の制約）

### 5. `create_release`
依存: `build`, `calc_tag`, `play_upload`
条件: `github.ref == 'refs/heads/main'`

- 既存 container ワークフローと同形式で:
  - `client-v...` タグを作成
  - 前タグからの commit 一覧で Release body を構築
  - **AAB と Windows インストーラー両方**をアセットとして添付
  - 内部リリース扱いとして `prerelease: true`
- `actions/download-artifact@v4` で両方の artifact を取得してから添付。
- アセット添付は `softprops/action-gh-release@v2` を使うのが簡潔。

## Inno Setup スクリプト

スクリプトの配置・設計方針・雛形・dev / prod 値の対応表は別ファイルに分離している。
詳細は [inno-setup-installer.md](./inno-setup-installer.md) を参照。

## 必要な GitHub Secrets / Variables

### リポジトリ Secrets（環境共通）
| 名前 | 用途 |
|------|------|
| `ANDROID_KEYSTORE_BASE64` | `upload-keystore.jks` を `base64 -w0` でエンコードした文字列 |
| `ANDROID_KEYSTORE_PASSWORD` | キーストアパスワード |
| `ANDROID_KEY_PASSWORD` | キーパスワード |
| `ANDROID_KEY_ALIAS` | キーエイリアス（例: `upload`） |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Play Console 用サービスアカウントの JSON 全文 |

### Environments（`dev` / `prod` で分離）
GitHub の **Environments** 機能を使い、`dev` と `prod` でそれぞれ次を登録:

#### Secrets
| 名前 | 用途 |
|------|------|
| `API_BASE_URL` | API サーバーのベース URL |
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuth クライアント ID |
| `INNO_APP_ID` | Inno Setup の `AppId`（GUID 文字列、波括弧込み） |

#### Variables（公開しても問題ない値は Variables へ）
| 名前 | 用途 |
|------|------|
| `INNO_APP_NAME` | インストーラー表示名（例: `TaskManager (Dev)` / `TaskManager`） |
| `INNO_INSTALL_DIR_NAME` | インストール先フォルダ名（例: `TaskManagerDev` / `TaskManager`） |
| `INNO_OUTPUT_BASENAME` | 出力ファイル名のプレフィックス（例: `task-manager-dev-setup` / `task-manager-setup`） |

ワークフローで `environment: ${{ github.event.inputs.environment }}` を指定して切り替える。

## ローカル準備手順（ユーザー作業）

キーストア生成・Google Play サービスアカウント発行・GitHub Environments / Secrets / Variables の登録・
Inno Setup AppId 生成・Play Console 初回手動アップロード等のユーザー作業手順は
[`.github/workflows/README.md`](../.github/workflows/README.md) に集約している。

## versionCode 採番ルール

`pubspec.yaml` の `version` を触らない方針のため、CI 側で `flutter build --build-number=<int>`
を使って `versionCode` を上書きする。値はタグ `client-vYYYY.MMDD.N` から下式で算出する。

```
versionCode = YY * 10_000_000
            + MM *    100_000
            + DD *      1_000
            + N
```

- `YY` = 西暦下2桁、`MM` = 月、`DD` = 日、`N` = 同日内連番（`calc_tag` で採番済み）
- 例: `client-v2026.0426.1` → `26*10000000 + 4*100000 + 26*1000 + 1 = 260426001`（9桁）
- 99 年まで桁あふれなし（Google Play 上限 2,100,000,000 内）
- 年→月→日→連番 の順で単調増加するため、Play Console の `versionCode` 重複拒否にかからない

`calc_tag` ジョブで以下を計算し `versionCode` を `outputs` に設定する。

```javascript
// actions/github-script 内に追記
const yy = year % 100;
const mm = d.getMonth() + 1;
const dd = d.getDate();
const versionCode = yy * 10000000 + mm * 100000 + dd * 1000 + next;
core.setOutput('versionCode', versionCode);
```

`versionName`（Play 表示用）は `pubspec.yaml` の値をそのまま使用し、CI からは上書きしない。
Play Console 上の「リリース名」は `r0adkll/upload-google-play` の `releaseName` で `tagName`
を渡すため、表示識別には十分。

Windows 側は Inno Setup の `AppVersion` に `tagName`（`client-vYYYY.MMDD.N`）をそのまま
入れる。Windows のインストーラー UI に表示される。

## 留意点 / オープン項目

- **Flutter のバージョン固定**: `flutter-action` で `flutter-version` または `channel` を指定。
  `pubspec.yaml` の `environment.sdk` に合わせて固定する。
- **キーストアの取り扱い**: ワークフロー終了時にランナーは破棄されるため明示削除は不要だが、
  `key.properties` をチェックインしないこと（既に `.gitignore` 想定）。
- **SmartScreen 警告**: コード署名なしのため、ユーザーは初回起動時に「WindowsによってPCが保護されました」
  ダイアログが出る。「詳細情報」→「実行」で進められる旨を Release ノートに記載しておくとよい。
- **将来のコード署名対応**: SignPath Foundation や有料証明書を導入する場合、
  Inno Setup の `[Setup] SignTool=...` を使うか、生成後の `.exe` に対して `signtool sign` を
  別ステップで実行する形に拡張する。`installer.iss` 自体の構造は変える必要がない。
- **`AppId` の固定**: dev / prod それぞれで一度決めた GUID を変えるとアップグレードできなくなり、
  ユーザー側で手動アンインストールが必要になる。Secrets に登録したら以降変えない。
- **`concurrency`**: `client-${{ inputs.environment }}` のように環境ごとに分ければ
  dev/prod 同時実行も可能。
- **Windows ランナーのキャッシュ**: `flutter pub get` のキャッシュを `actions/cache` で
  有効化すると Windows ビルドが体感で大きく速くなる（任意）。

## 全体フロー

```
workflow_dispatch (environment: dev|prod)
        │
        ├──► calc_tag (client-vYYYY.MMDD.N + versionCode)
        │
        └──► prepare (platforms matrix JSON)
                │
                ▼ (needs: calc_tag, prepare)
             build [matrix: android, windows]
              ├─ android: AAB                  → artifact: android-aab
              └─ windows: build windows + iscc → artifact: windows-installer
                │
                ├──► play_upload (android: Internal track へ公開)
                │
                └──► create_release (タグ作成 + Release + AAB & .exe 添付, main 限定)
```
