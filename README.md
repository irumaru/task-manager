# Task Manager

シンプルで軽量なTodoアプリ。Android / iOS / Windows / macOS に対応。

## 技術スタック

| 用途 | ライブラリ |
|---|---|
| フレームワーク | Flutter 3.41.4 |
| 状態管理 | Riverpod 2.x |
| ローカルDB | drift (SQLite) |
| コード生成 | build_runner |

## 開発環境のセットアップ

### 前提条件

- Flutter SDK (`C:\Users\jibak\sdk\flutter`)
- Android Studio（Android エミュレータ・SDK 管理用）
- Git

### PATH の設定

Flutter コマンドを使えるように PATH を通してください。

**Windows（永続設定）**
システム環境変数の `Path` に以下を追加：
```
C:\Users\jibak\sdk\flutter\bin
```

設定後、新しいターミナルを開いて確認：
```bash
flutter --version
```

### セットアップ手順

```bash
# 1. リポジトリのクローン
git clone <repository-url>
cd task-manager

# 2. 依存パッケージのインストール
cd app
flutter pub get

# 3. コード生成（drift・Riverpod のコードを生成）
flutter pub run build_runner build --delete-conflicting-outputs
```

### 環境確認

```bash
flutter doctor
```

必要なコンポーネントがすべて緑になっていることを確認してください。

## 開発コマンド

### アプリの起動

```bash
cd app

# 接続中のデバイスを確認
flutter devices

# Windows で起動
flutter run -d windows

# Android エミュレータで起動
flutter run -d android

# 特定デバイスを指定して起動（デバイスIDを使う場合）
flutter run -d <device-id>

# 環境変数を指定して実行
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=GOOGLE_OAUTH_CLIENT_ID=729359629726-1edq8brg5hksql8q65v0cpn5maqud0vj.apps.googleusercontent.com -d Windows
```

### コード生成

drift（DB）や Riverpod のコードは自動生成です。モデル・テーブル定義を変更したら再実行してください。

```bash
# 一度だけ生成
flutter pub run build_runner build --delete-conflicting-outputs

# ファイル変更を監視して自動生成
flutter pub run build_runner watch --delete-conflicting-outputs
```

### ビルド

```bash
# Windows 向けリリースビルド
flutter build windows

# Android 向けリリースビルド（APK）
flutter build apk

# Android 向けリリースビルド（App Bundle）
flutter build appbundle

# macOS 向けリリースビルド（macOS 環境が必要）
flutter build macos

# iOS 向けリリースビルド（macOS + Xcode が必要）
flutter build ios
```

## プロジェクト構成

```
task-manager/
├── app/                        # Flutterプロジェクト
│   ├── lib/
│   │   ├── main.dart           # エントリーポイント
│   │   ├── app.dart            # アプリルート・テーマ設定
│   │   ├── core/               # 定数・テーマ・ユーティリティ
│   │   ├── data/               # DB・リポジトリ
│   │   └── presentation/       # 画面・ウィジェット・プロバイダー
│   ├── test/                   # テスト
│   └── pubspec.yaml            # パッケージ定義
└── docs/                       # 設計ドキュメント
    ├── specification.md        # 仕様書
    └── directory-structure.md  # ディレクトリ構成
```

## iOS / macOS ビルドについて

iOS・macOS のビルドには **macOS マシンと Xcode** が必要です。Windows 環境では Android・Windows ビルドのみ可能です。

CI/CD（GitHub Actions の macOS ランナー）を使う方法もあります。
