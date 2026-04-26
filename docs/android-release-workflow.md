# Flutter Android 内部リリース GitHub Actions 計画

Flutter クライアント (`app/`) の Android AAB を GitHub Actions でビルドし、
Google Play Console の内部テストトラックへ自動アップロードする。
GitHub Release も併せて作成し、生成された AAB をアセットとして添付する。

## 方針

- 既存 [`.github/workflows/build-and-release-container.yml`](../.github/workflows/build-and-release-container.yml) を参考にする。
- 新規ファイル: `.github/workflows/build-and-release-android.yml`
- トリガー: `workflow_dispatch`（手動実行）
- 環境 (env): `dev` / `prod` を `workflow_dispatch.inputs.environment` で選択。
  - `API_BASE_URL`, `GOOGLE_OAUTH_CLIENT_ID` を環境ごとに Secrets で切り替える。
- 成果物: **AAB のみ**（`flutter build appbundle --release`）
- タグ命名: `client-vYYYY.MMDD.N`
  - 既存 container ワークフローの `vYYYY.MMDD.N` と分離。
  - `calc_tag` ジョブで `client-v` プレフィックス付きの最新番号を走査して採番。
- `pubspec.yaml` の `version` はリリース時に変更しない（手動運用のまま）。

## ジョブ構成

### 1. `calc_tag`
- `actions/github-script@v8` で `client-vYYYY.MMDD.N` の次番号を算出。
- 同時に `versionCode` も算出する（後述「versionCode 採番ルール」参照）。
- 出力: `tagName`, `versionCode`

### 2. `prepare`
- ビルド対象プラットフォームの matrix JSON を出力する。
- 現在は `[{"platform":"android","runner":"ubuntu-latest"}]` のみ。
- Windows ビルド追加時はここに `{"platform":"windows","runner":"windows-latest"}` を追記する。
- 出力: `platforms`

### 3. `build`
依存: `calc_tag`, `prepare`

ステップ:
1. `actions/checkout@v6`
2. `actions/setup-java@v4`（distribution: temurin, java-version: 17）
3. `subosito/flutter-action@v2`（channel: stable、`pubspec.yaml` の SDK 制約に合わせる）
4. キーストア復元
   - `ANDROID_KEYSTORE_BASE64` を `base64 -d` して `app/android/app/upload-keystore.jks` に書き出す。
   - `app/android/key.properties` を生成:
     ```properties
     storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
     keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
     keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
     storeFile=upload-keystore.jks
     ```
   - `storeFile` は [`app/android/app/build.gradle.kts`](../app/android/app/build.gradle.kts) の `signingConfigs.release` が `file(...)` で解決するため、`app/` モジュール基準の相対パス（`upload-keystore.jks`）で OK。
5. `flutter pub get`（`working-directory: app`）
6. AAB ビルド（`--build-number` で `versionCode` を上書き）:
   ```bash
   flutter build appbundle --release \
     --build-number=${{ needs.calc_tag.outputs.versionCode }} \
     --dart-define=API_BASE_URL=${{ secrets.API_BASE_URL }} \
     --dart-define=GOOGLE_OAUTH_CLIENT_ID=${{ secrets.GOOGLE_OAUTH_CLIENT_ID }}
   ```
7. `actions/upload-artifact@v4` で `app/build/app/outputs/bundle/release/app-release.aab` をアーティファクト化（後続ジョブが取得するため）。

### 4. `play_upload`
依存: `build`, `calc_tag`

- `actions/download-artifact@v4` で AAB を取得
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
  - AAB をアセットとして添付
  - 内部リリース扱いとして `prerelease: true`
- アセット添付は `actions/github-script` で `repos.uploadReleaseAsset` を呼ぶか、
  シンプルに `softprops/action-gh-release@v2` を使う方針も可。

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
GitHub の **Environments** 機能を使い、`dev` と `prod` でそれぞれ次の Secrets を登録:

| 名前 | 用途 |
|------|------|
| `API_BASE_URL` | API サーバーのベース URL |
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuth クライアント ID |

ワークフローで `environment: ${{ github.event.inputs.environment }}` を指定して切り替える。

## ローカル準備手順（ユーザー作業）

1. **キーストアを base64 化して Secrets 登録**
   ```powershell
   # Windows (PowerShell)
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
   ```
   または
   ```bash
   # WSL / Linux
   base64 -w0 ~/upload-keystore.jks
   ```
   出力を `ANDROID_KEYSTORE_BASE64` に登録。

2. **Google Play サービスアカウント発行**
   - [Google Cloud Console](https://console.cloud.google.com/) でサービスアカウント作成 → JSON キー発行
   - [Google Play Console](https://play.google.com/console) → 「ユーザーと権限」→ 上記サービスアカウントを招待
     - 権限: 少なくとも「リリース管理」の「リリースの作成・編集」「内部テストトラックへの公開」
   - 発行 JSON を `PLAY_SERVICE_ACCOUNT_JSON` に登録

3. **GitHub Environments 作成**
   - Settings → Environments で `dev` / `prod` を作成
   - それぞれに `API_BASE_URL` / `GOOGLE_OAUTH_CLIENT_ID` を登録
   - `prod` には保護ルール（手動承認等）を付けるのが望ましい

4. **Play Console 初回手動アップロード**
   - 内部テストトラックに最初の AAB を一度手動でアップロードする
   - これをやっておかないと API からのアップロードで `package not found` 系エラーになる

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

## 留意点 / オープン項目

- **Flutter のバージョン固定**: `flutter-action` で `flutter-version` または `channel` を指定。
  `pubspec.yaml` の `environment.sdk` に合わせて固定する。
- **キーストアの取り扱い**: ワークフロー終了時にランナーは破棄されるため明示削除は不要だが、
  `key.properties` をチェックインしないこと（既に `.gitignore` 想定）。
- **`prepare` ジョブと matrix 構成を維持**: 現在は Android のみだが、今後 Windows ビルドを追加する際に
  `prepare` ジョブの platforms リストへ `{"platform":"windows","runner":"windows-latest"}` を追記するだけで対応できる。
  platform 固有ステップは `if: matrix.platform == 'android'` などで分岐する。
- **`concurrency`**: `client-android-${{ inputs.environment }}` のように環境ごとに分ければ
  dev/prod 同時実行も可能。

## 全体フロー

```
workflow_dispatch (environment: dev|prod)
        │
        ├──► calc_tag (client-vYYYY.MMDD.N + versionCode)
        │
        └──► prepare (platforms matrix JSON)
                │
                ▼ (needs: calc_tag, prepare)
             build [matrix: android / (将来: windows)]
                │
                ├──► play_upload (android: Internal track へ公開)
                │
                └──► create_release (タグ作成 + Release + AAB 添付, main 限定)
```
