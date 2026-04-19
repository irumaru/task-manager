# task_manager (Flutter App)

タスク管理アプリのFlutterクライアント。

## 必要な環境

- Flutter 3.x以上
- Android SDK（Androidビルド用）
- Xcode（iOSビルド用、macOSのみ）

## 環境変数

ビルド・実行時に以下の`--dart-define`が必要です：

| 変数名 | 説明 |
|--------|------|
| `API_BASE_URL` | APIサーバーのベースURL |
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuthクライアントID |

## 開発用（ローカル実行）

```bash
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-client-id> \
  -d <device>
```

## Android実機でのデバッグ

### 1. 実機側の準備

1. 「設定」→「デバイス情報」→ **ビルド番号** を7回タップして開発者オプションを有効化
2. 「設定」→「開発者オプション」→ **USBデバッグ** をオン
3. USBケーブルでPCと接続し、デバイス側で表示される「USBデバッグを許可しますか？」を許可

### 2. 接続確認

```bash
flutter devices
```

接続した実機がリストに表示されれば準備完了です。表示されない場合は `adb devices` で確認してください。

### 3. 実行

```bash
flutter run \
  --dart-define=API_BASE_URL=https://<your-api-host> \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-client-id> \
  -d <device-id>
```

`<device-id>` は `flutter devices` の出力に表示されるID。

## リリースビルド（Android）

### 事前準備：署名設定

1. キーストアを生成（初回のみ）：

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" `
  -genkey -keystore "$HOME\upload-keystore.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload `
  -dname "CN=<your-name>, C=<country-code>" `
  -storepass <password> -keypass <password>
```

2. `android/key.properties` を作成（Gitにコミットしないこと）：

```properties
storePassword=<設定したパスワード>
keyPassword=<設定したパスワード>
keyAlias=upload
storeFile=C:\\Users\\<username>\\upload-keystore.jks
```

### AABビルド（Google Play用）

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://<your-api-host> \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-client-id>
```

出力先: `build/app/outputs/bundle/release/app-release.aab`

### APKビルド（直接インストール用）

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<your-api-host> \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-client-id>
```

出力先: `build/app/outputs/flutter-apk/app-release.apk`

## Google Play 内部テスト公開

1. [Google Play Console](https://play.google.com/console) でアプリを作成
2. **内部テスト** トラックにAABをアップロード
3. テスターのGoogleアカウントを登録し、招待リンクを共有
