# やりたいこと機能 要件定義書

## 1. 概要

タスク管理アプリに、気軽にメモできる「やりたいこと」機能を追加する。
タスクほど厳格に管理する必要がないが記録しておきたいアイデア・願望・興味を、テキストとラベル（複数付与可）で蓄積し、後からラベルで絞り込んで一覧できるようにする。

本機能は既存の Task Manager API と Flutter クライアント（`api/`, `app/`）に統合し、全端末で同期される。

---

## 2. 用語

| 用語 | 意味 |
|---|---|
| やりたいこと（wish）| ユーザーがメモしたテキスト1件。本機能の主エンティティ |
| ラベル（label） | やりたいことに付与する分類ラベル。複数付与可能 |

「タスク用のタグ（既存 `tags` テーブル）」とは**独立した別概念**とする。データも画面も共有しない。

---

## 3. スコープ

### 3.1 対象

- 「やりたいこと」の登録・編集・削除・一覧表示
- 「ラベル」の登録・編集・削除
- やりたいこと一覧でのラベルによる絞り込み
- 既存 API への機能追加（TypeSpec / schema.sql / ハンドラ / リポジトリ）
- Flutter クライアントの画面追加と既存メニューへの導線追加
- WebSocket による他端末へのリアルタイム反映

### 3.2 非対象（本フェーズでは扱わない）

- やりたいこと → タスク化（変換）機能
- やりたいことの並び替え / ソート機能（一覧は作成日時の降順固定）
- ラベルのカラー指定・アイコン指定
- キーワード検索
- やりたいことに対する期限・優先度・ステータスの概念

---

## 4. 機能要件

### 4.1 やりたいこと管理

| 機能 | 内容 |
|---|---|
| 追加 | タイトル（必須）・詳細（任意）・ラベル（0件以上、複数可）を指定して作成 |
| 編集 | タイトル・詳細・付与ラベルを後から変更可能 |
| 削除 | 個別削除（確認ダイアログあり） |
| 一覧 | 認証ユーザーのやりたいこと全件を作成日時の降順で表示 |

### 4.2 やりたいことの属性

| 属性 | 型 | 必須 | 詳細 |
|---|---|---|---|
| タイトル（title） | テキスト（単一行） | ✓ | 1文字以上、空白のみは不可。改行は含まない |
| 詳細（detail） | テキスト（複数行） | - | 空欄可。改行を含む長文を許容 |
| ラベル | ラベルの集合 | - | 0件以上。同じラベルを2重付与しない |
| 作成日時 | 日時 | ✓ | 自動設定 |
| 更新日時 | 日時 | ✓ | 自動更新 |

### 4.3 ラベル

- ユーザーごとに管理される（マルチテナント）
- ラベル名は自由入力（テキスト、1文字以上）
- **同じユーザー内ではラベル名は一意**（重複登録不可）
- ラベルを削除すると、そのラベルが付与されていたすべてのやりたいことから当該ラベルが自動的に外れる（やりたいこと自体は削除されない）
- ラベルは「設定」画面のサブ画面（ラベル管理）から追加・編集・削除できる
- 新しいやりたいことを登録する際にも、入力途中で新規ラベルを作成できる（任意、後述 4.6 参照）

### 4.4 一覧表示

- ログインユーザーのやりたいこと全件を取得する
- 表示順は**作成日時の降順（新しい順）で固定**
- 1件のカードに表示する情報:
  - タイトル（単一行・太字などで強調）
  - 付与されているラベル（Chip などで横並び）
  - 作成日時（相対表示可: 「3日前」など）
- 0件の場合は空状態メッセージ（例: 「やりたいことを追加してみましょう」）を表示

### 4.5 フィルタリング

ラベルによる絞り込みを1つだけ提供する。

| 項目 | 内容 |
|---|---|
| UI | 画面上部のプルダウン（ドロップダウン）1つ |
| 選択肢 | 「すべて」 + 登録済みラベル一覧（ラベル名の昇順） |
| 既定値 | 「すべて」 |
| 動作 | 「すべて」選択時は全件表示。ラベルを選択した場合、**そのラベルが付与されているやりたいこと**のみを表示 |
| 複数選択 | サポートしない（本フェーズでは単一選択のみ） |

### 4.6 追加／編集画面の入力仕様

- タイトル: **単一行**テキスト入力（改行は入力不可、Enter で送信はしない）
- 詳細: **複数行**テキスト入力（任意、空欄可、改行を含められる）
- ラベル選択 UI:
  - 登録済みラベル一覧から複数選択できる（マルチセレクト Chip）
  - 未登録の名前を入力して「追加」で新規ラベルを作成し、そのまま付与できる（既存タスクの `task_form_page.dart` と同様の体験）
- 空文字のタイトルは保存不可（保存ボタン無効化）。詳細は空欄で保存可

---

## 5. データモデル

`taskmanager` スキーマに新規3テーブルを追加する。既存の `tags` / `task_tags` には手を入れない。

### 5.1 wishes テーブル（やりたいこと本体）

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | UUID | PK, default `gen_random_uuid()` | 自動採番 |
| user_id | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | 所有ユーザー |
| title | TEXT | NOT NULL | タイトル（単一行） |
| detail | TEXT | NULL 可 | 詳細（複数行、空欄可） |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | 作成日時 |
| updated_at | TIMESTAMPTZ | NOT NULL, default NOW() | 更新日時 |

- アプリ層でタイトルに改行文字（`\n` / `\r`）が含まれないことをバリデーションする

### 5.2 wish_labels テーブル（ラベル定義）

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| id | UUID | PK, default `gen_random_uuid()` | 自動採番 |
| user_id | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | 所有ユーザー |
| name | TEXT | NOT NULL | ラベル名 |
| created_at | TIMESTAMPTZ | NOT NULL, default NOW() | 作成日時 |
| updated_at | TIMESTAMPTZ | NOT NULL, default NOW() | 更新日時 |

- `UNIQUE (user_id, name)` 制約を付与する（同一ユーザー内の重複禁止）

### 5.3 wish_label_assignments テーブル（中間テーブル）

| カラム名 | 型 | 制約 | 説明 |
|---|---|---|---|
| wish_id | UUID | NOT NULL, FK → wishes.id ON DELETE CASCADE | やりたいことID |
| wish_label_id | UUID | NOT NULL, FK → wish_labels.id ON DELETE CASCADE | ラベルID |

- PRIMARY KEY は `(wish_id, wish_label_id)`
- どちらの親が消えても紐付けは自動削除される（CASCADE）
- これにより「ラベル削除時に、そのラベルを持つやりたいことからもラベルが自動的に外れる」要件が満たせる

### 5.4 既存スキーマとの関係

- 既存の `tasks` / `tags` / `task_tags` とは**完全に独立**している
- 既存 `users` テーブルを親として参照するのみ

---

## 6. API設計（TypeSpec 追加案）

すべて `BearerAuth` 必須。

**更新は PUT（全置換）を採用する**。既存のタスク/タグ/ステータス/優先度は PATCH（部分更新）だが、本機能のみ PUT とする。理由と詳細は [設計書 1.3.1](./wishes-design.md) を参照。クライアントは更新時にリソース全体（title / detail / labelIds）を送る必要がある。

### 6.1 やりたいこと（/wishes）

| メソッド | パス | 用途 |
|---|---|---|
| GET | `/wishes` | 一覧取得（自分のやりたいこと全件） |
| POST | `/wishes` | 新規作成 |
| GET | `/wishes/{id}` | 単体取得 |
| PUT | `/wishes/{id}` | 更新（全置換） |
| DELETE | `/wishes/{id}` | 削除 |

クエリパラメータでのサーバ側フィルタは**提供しない**（クライアント側で絞り込む）。

### 6.2 ラベル（/wish-labels）

| メソッド | パス | 用途 |
|---|---|---|
| GET | `/wish-labels` | ラベル一覧 |
| POST | `/wish-labels` | 新規作成 |
| PUT | `/wish-labels/{id}` | 更新（全置換、改名） |
| DELETE | `/wish-labels/{id}` | 削除（中間テーブルはCASCADE） |

### 6.3 モデル（TypeSpec 概形）

```typespec
model Wish {
  id: string;
  title: string;
  detail: string | null;
  labelIds: string[];
  createdAt: utcDateTime;
  updatedAt: utcDateTime;
}

model CreateWishRequest {
  title: string;
  detail?: string;
  labelIds?: string[];
}

// PUT セマンティクス: 全フィールド必須。リソース全体を差し替える。
model UpdateWishRequest {
  title: string;
  detail: string | null;
  labelIds: string[];
}

model WishList {
  items: Wish[];
}

model WishLabel {
  id: string;
  name: string;
}

model WishLabelList {
  items: WishLabel[];
}

model CreateWishLabelRequest {
  name: string;
}

// PUT セマンティクス: `name` 必須。
model UpdateWishLabelRequest {
  name: string;
}
```

### 6.4 バリデーション

| 対象 | ルール | エラー |
|---|---|---|
| `Wish.title` | 空文字・空白のみは不可 | 400 ApiError |
| `Wish.title` | 改行文字（`\n` / `\r`）を含まない | 400 ApiError |
| `Wish.detail` | 任意。空文字または null を許容 | - |
| `WishLabel.name` | 空文字・空白のみは不可 | 400 ApiError |
| `WishLabel.name` | 同一ユーザー内での重複 | 409 ApiError（既存のタグと同じ扱い） |
| 存在しない `labelIds` を指定 | 400 ApiError |

---

## 7. WebSocket イベント

既存の `internal/websocket/` の Hub を利用し、以下のイベントを追加する。

| イベント名 | 発火タイミング | ペイロード |
|---|---|---|
| `wish.changed` | やりたいこと作成／更新／削除のいずれか | `{}`（空オブジェクト） |
| `wish_label.changed` | ラベル作成／更新／削除のいずれか | `{}`（空オブジェクト） |

クライアントはこのイベントを受けて該当 provider のキャッシュを破棄し、再取得する。個別の create/update/delete 区別やエンティティ本体のペイロードは、本フェーズでは不要（楽観更新などで必要になった時点で細分化を検討する）。

本機能では `internal/websocket/Hub.Broadcast` を **CRUD ハンドラから実際に呼ぶ**。既存の `tasks` / `tags` 等は Hub インターフェイスは定義されているが呼び出しは未実装で、本機能が最初の配線となる。既存エンドポイントの broadcast 配線は本機能のスコープ外とし、別途対応する（詳細は [設計書 1.1](./wishes-design.md) / [4.4](./wishes-design.md) を参照）。

---

## 8. 画面構成（Flutter クライアント）

### 8.1 ナビゲーションへの追加

`app/lib/app.dart` の `MainShell` の `NavigationBar` に「やりたいこと」を追加する。

```
┌───────────┬──────────────────┬───────────┐
│ タスク     │ やりたいこと      │ 設定      │
│ ✓         │ ☆                │ ⚙         │
└───────────┴──────────────────┴───────────┘
```

アイコンは `Icons.lightbulb_outline` または `Icons.star_outline` を想定（実装時に確定）。

### 8.2 画面一覧

| 画面 | 役割 |
|---|---|
| やりたいこと一覧画面 | ラベルフィルタ（プルダウン）＋やりたいことカード一覧＋FABで追加 |
| やりたいこと追加／編集画面 | タイトル（単一行）＋詳細（複数行・任意）＋ラベル複数選択。既存 `task_form_page.dart` の構造を踏襲 |
| ラベル管理画面 | 「設定」画面内のサブページ。ラベルの一覧・追加・改名・削除 |

### 8.3 一覧画面のレイアウト（ASCII）

```
┌────────────────────────────────────┐
│ やりたいこと                          │
│ ┌──────────────────┐                │
│ │ ラベル: すべて ▼   │                │
│ └──────────────────┘                │
│                                    │
│ ┌──────────────────────────────┐   │
│ │ 本屋でふらっと時間をつぶす        │   │
│ │ [読書] [休日]      3日前        │   │
│ └──────────────────────────────┘   │
│ ┌──────────────────────────────┐   │
│ │ 朝のカフェで作業してみる         │   │
│ │ [仕事] [習慣化]    1週間前       │   │
│ └──────────────────────────────┘   │
│                                    │
│                             ( + ) │
└────────────────────────────────────┘
```

### 8.4 状態管理

- Riverpod 3.x / `riverpod_generator` を使用（既存のタスク実装と同じ構成）
- `data/` → `domain/` → `presentation/` のレイヤ分離を踏襲
- WebSocket 受信時にプロバイダのキャッシュを更新し、一覧が自動で再描画されるようにする

---

## 9. 非機能要件

| 項目 | 内容 |
|---|---|
| 認証 | 既存の JWT（HS256 Bearer）を必須とする |
| マルチテナント | すべての行は `user_id` に紐付き、他ユーザーのデータは一切見えない |
| 同期 | 既存 WebSocket Hub にイベントを追加し、複数端末でリアルタイム反映 |
| UI 言語 | 日本語 |
| プラットフォーム | Android / iOS / Windows / macOS（既存と同じ） |

---

## 10. コード生成パイプラインへの影響

本機能の追加は、既存のコード生成パイプライン（`mise run gen`）に沿って行う。

| 手書きで編集するファイル | 自動生成されるもの |
|---|---|
| `spec/main.tsp` に Wish / WishLabel のモデルとエンドポイントを追記 | `spec/tsp-output/openapi.yaml`, `api/internal/api/oas_*_gen.go` |
| `schema.sql` に 5章の3テーブルを追加 | `migrator/migrations/*.sql`（atlas diff で生成） |
| `api/internal/db/queries/*.sql` に wish / wish_label 用クエリを追加 | `api/internal/repository/*.sql.go`（sqlc） |
| `api/internal/handler/` に wishes.go / wish_labels.go を新設（手書き） | - |
| `app/` 配下に data / domain / presentation のコードを追加（手書き） | - |

生成後は `mise run gen` の結果を必ずコミットし、`test-generated.yml` を通す。

---

## 11. テスト方針

| 種別 | 対象 |
|---|---|
| リポジトリ結合テスト（`api/internal/repository-test/`）| wishes / wish_labels の CRUD、および「ラベル削除で中間テーブルの行が消えること」の検証 |
| E2E（`api/e2e/scenarios/`） | 「作成→一覧→更新→削除」「ラベル作成→やりたいこと作成→ラベル削除でラベルが自動的に外れる」 |
| Flutter 側 | フィルタ挙動（「すべて」と特定ラベル）、追加・編集・削除フロー |

---

## 12. マイグレーション／リリース手順

1. `spec/main.tsp` を編集して `mise run gen:tsp` → `mise run gen:go:ogen`
2. `schema.sql` を編集
3. `api/internal/db/queries/` にクエリを追加して `mise run gen:go:sqlc`
4. API ハンドラ・リポジトリのブリッジ実装
5. Flutter クライアント実装
6. E2E 追加

---

## 13. オープンイシュー（今後の検討）

| 項目 | 検討内容 |
|---|---|
| やりたいこと → タスク化 | 将来的に「このやりたいことをタスクに昇格する」フロー |
| キーワード検索 | 本文に対する全文検索 |
| ラベル共通化 | `tags` と `wish_labels` を長期的に統合するかどうか |
| 並び順のカスタマイズ | 任意順・手動並べ替え |
| ラベルの色分け | UI 上の識別性向上のため |
