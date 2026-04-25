# Task Manager

クラウド対応のタスク管理アプリ。Go REST API + Flutter クライアント + PostgreSQL で構成され、Google OAuth 認証とWebSocketによるリアルタイム同期をサポート。

## アーキテクチャ概要

本プロジェクトは3つのコンポーネントで構成されています。

| コンポーネント | 説明 |
|---|---|
| **API** (`api/`) | Go製のREST APIサーバー。認証・データアクセス・WebSocket を担当 |
| **Flutter App** (`app/`) | クロスプラットフォーム対応のクライアントアプリ（Android / iOS / Windows / macOS） |
| **Migrator** (`migrator/`) | Atlas を使用したデータベースマイグレーションランナー |

補助ディレクトリ:
- `spec/` — TypeSpec で記述された API 仕様（OpenAPI 生成元）
- `docs/` — 設計ドキュメント

## 技術スタック

### API（`api/`）

| 用途 | ツール / ライブラリ |
|---|---|
| 言語 | Go 1.26.1 |
| API コード生成 | ogen（OpenAPI → サーバーコード） |
| DB アクセスコード生成 | sqlc（SQL → Go コード） |
| PostgreSQL ドライバー | pgx/v5 |
| 認証 | golang-jwt/jwt v5（HS256） |
| WebSocket | gorilla/websocket |
| E2E テスト | runn |
| ホットリロード（開発用） | Air |

### クライアント（`app/`）

| 用途 | ライブラリ |
|---|---|
| フレームワーク | Flutter（Dart SDK ^3.11.1） |
| 状態管理 | Riverpod 3.x + riverpod_generator |
| HTTP クライアント | dio |
| WebSocket | web_socket_channel |
| 認証トークン保存 | flutter_secure_storage |
| コード生成 | build_runner |

### インフラ・ツールチェーン

| 用途 | ツール |
|---|---|
| データベース | PostgreSQL 18 |
| マイグレーション | Atlas |
| コンテナ | Docker / Docker Compose |
| API 仕様定義 | TypeSpec |
| ツールバージョン管理 | mise |
| CI/CD | GitHub Actions |
| コンテナレジストリ | GitHub Container Registry（ghcr.io） |

## プロジェクト構成

```
task-manager/
├── api/                            # Go REST API サーバー
│   ├── cmd/server/main.go          #   エントリーポイント
│   ├── internal/
│   │   ├── api/                    #   ogen 生成コード（サーバー・型・ルーター）
│   │   ├── auth/                   #   JWT・Google OAuth・SecurityHandler
│   │   ├── bootstrap/              #   DB接続プール初期化
│   │   ├── db/queries/             #   SQLクエリ（sqlc入力）
│   │   ├── handler/                #   ハンドラー実装
│   │   ├── repository/             #   sqlc 生成コード（DBアクセス）
│   │   ├── repository-test/        #   DB統合テスト
│   │   ├── testfactory/            #   テストデータファクトリ
│   │   ├── testutils/              #   テストユーティリティ
│   │   └── websocket/              #   WebSocket Hub・接続管理
│   ├── e2e/                        #   E2Eテスト（runn）
│   ├── Dockerfile                  #   本番用
│   ├── Dockerfile.dev              #   開発用（Air ホットリロード）
│   └── sqlc.yaml                   #   sqlc 設定
├── app/                            # Flutter クライアント
│   ├── lib/
│   │   ├── main.dart               #   エントリーポイント
│   │   ├── app.dart                #   アプリルート・テーマ設定
│   │   ├── core/                   #   定数・テーマ・ユーティリティ
│   │   ├── data/                   #   APIクライアント・リポジトリ実装・認証
│   │   ├── domain/                 #   モデル・リポジトリインターフェース
│   │   └── presentation/           #   画面・プロバイダー・ウィジェット
│   └── pubspec.yaml
├── migrator/                       # DBマイグレーションランナー（Atlas）
│   ├── Dockerfile
│   └── migrations/
├── spec/                           # API仕様（TypeSpec）
│   ├── main.tsp                    #   API定義
│   ├── tspconfig.yaml
│   └── tsp-output/openapi.yaml     #   生成された OpenAPI 仕様
├── docs/                           # 設計ドキュメント
├── schema.sql                      # PostgreSQL スキーマ定義（単一ソース）
├── docker-compose.yml              # ローカル開発用（DB + API）
├── .env.example                    # 環境変数テンプレート
└── .mise.toml                      # ツールバージョン・タスク定義
```

## 開発環境のセットアップ

### 前提条件

- [mise](https://mise.jdx.dev/)（Go, sqlc, atlas, Node.js, pnpm, ogen を自動管理）
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Docker](https://docs.docker.com/get-started/) / Docker Compose
- Git

### セットアップ手順

```bash
# 1. リポジトリのクローン
git clone <repository-url>
cd task-manager

# 2. mise でツールをインストール
mise install

# 3. 環境変数の設定
cp .env.example .env
# .env を編集して JWT_SECRET, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET を設定
# JWT_SECRET生成の例: openssl rand -hex 32

# 4. TypeSpec の依存パッケージをインストール
cd spec && pnpm install && cd ..

# 5. コード生成
mise run gen

# 6. DB とAPIサーバーを起動
docker compose up -d

# 7. DBスキーマを適用
mise run db:migrate

# 8. Flutter アプリの依存パッケージをインストール
cd app && flutter pub get

# 9. Flutter のコード生成（Riverpod）
flutter pub run build_runner build --delete-conflicting-outputs
```

#### Flutter アプリの起動

```bash
cd app

# 環境変数を指定して起動
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=<your-client-id> \
  -d <device>

# デバイス例: windows, android, macos, ios, chrome
flutter devices  # 利用可能なデバイスを確認
```

#### 環境変数

| 変数名 | 説明 |
|---|---|
| `JWT_SECRET` | JWT署名キー（HS256） |
| `GOOGLE_CLIENT_ID` | Google OAuth クライアントID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth クライアントシークレット |


## コード生成パイプライン

本プロジェクトでは手書きの定義ファイルからコードを自動生成しています。

```
spec/main.tsp（TypeSpec 手書き）
  ↓ tsp compile
spec/tsp-output/openapi.yaml（OpenAPI 3.0）
  ↓ ogen
api/internal/api/oas_*_gen.go（サーバーインターフェース・型・ルーター）

schema.sql（PostgreSQL スキーマ 手書き）
  ↓ sqlc generate
api/internal/repository/*.sql.go（DBアクセスコード）

schema.sql
  ↓ atlas migrate diff
migrator/migrations/*.sql（マイグレーションファイル）
```

スキーマや API 仕様を変更した場合は `mise run gen` で再生成し、生成ファイルをコミットしてください。

## CI/CD

### `test-generated.yml`（PR時に自動実行）

生成ファイルがコミット済みの定義ファイルと同期しているかを検証します。コード生成の実行忘れを防止します。

### `build-and-release-container.yml`（手動実行）

`api` と `migrator` の Docker イメージをビルドし、GitHub Container Registry（`ghcr.io`）にプッシュします。`main` ブランチでの実行時は CalVer 形式（`vYYYY.MMDD.N`）で GitHub Release を作成します。

## API 仕様

API の詳細な仕様は TypeSpec で記述された [spec/main.tsp](spec/main.tsp) を参照してください（OpenAPI はこの定義から生成されます）。

### エンドポイント一覧

| メソッド | パス | 説明 |
|---|---|---|
| POST | `/auth/google` | Google IDトークンでログイン |
| POST | `/auth/google/code` | Google 認可コードでログイン |
| GET | `/auth/me` | 認証ユーザー情報を取得(JWT Bearer 認証が必要) |
| GET / POST | `/tasks` | タスクの一覧取得・作成 |
| GET / PATCH / DELETE | `/tasks/{id}` | タスクの取得・更新・削除 |
| GET / POST | `/statuses` | ステータスの一覧取得・作成 |
| PATCH / DELETE | `/statuses/{id}` | ステータスの更新・削除 |
| GET / POST | `/priorities` | 優先度の一覧取得・作成 |
| PATCH / DELETE | `/priorities/{id}` | 優先度の更新・削除 |
| GET / POST | `/tags` | タグの一覧取得・作成 |
| PATCH / DELETE | `/tags/{id}` | タグの更新・削除 |
| GET | `/ws?token=<JWT>` | WebSocket接続（リアルタイムイベント配信） |

全エンドポイント（`/auth/*` を除く）は JWT Bearer 認証が必要です。
