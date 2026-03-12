# 実装計画

## フェーズ構成

```
Step 1: プロジェクト初期化
Step 2: データ層（DB・リポジトリ）
Step 3: プレゼンテーション層（画面・UI）
Step 4: 動作確認・調整
```

---

## Step 1: プロジェクト初期化

### 1-1. Flutterプロジェクト作成
- `flutter create` でプロジェクトを生成
- 対応プラットフォーム（Android / iOS / Windows / macOS）を有効化

### 1-2. パッケージ導入
- `pubspec.yaml` に依存パッケージを追加
  - `flutter_riverpod` / `riverpod_annotation` / `riverpod_generator`
  - `drift` / `sqlite3_flutter_libs` / `path_provider` / `path`
  - `build_runner` / `drift_dev`

### 1-3. ディレクトリ構成の作成
- `lib/` 以下のフォルダ構成を作成

### 1-4. アプリ基盤の設定
- テーマ・カラー設定（`app_theme.dart`）
- ルーティング設定（`app.dart`）
- Riverpod の `ProviderScope` 設定（`main.dart`）

---

## Step 2: データ層

### 2-1. DBテーブル定義（drift）
以下のテーブルを定義する。

| ファイル | テーブル |
|---|---|
| `tasks_table.dart` | tasks |
| `priorities_table.dart` | priorities |
| `statuses_table.dart` | statuses |
| `tags_table.dart` | tags |
| `task_tags_table.dart` | task_tags（中間テーブル）|

### 2-2. DBクラス・コード生成
- `app_database.dart` に全テーブルを登録
- `build_runner` でコード自動生成
- 初期データ投入（デフォルトの優先度・ステータス）

### 2-3. リポジトリインターフェース定義（domain層）
- `task_repository.dart` など各リポジトリの抽象クラスを定義
- メソッド例: `getTasks()` / `addTask()` / `updateTask()` / `deleteTask()`

### 2-4. リポジトリ実装（data層）
- インターフェースに基づきSQLiteへのCRUDを実装
- タスク検索・フィルタリング・ソートのクエリを実装

---

## Step 3: プレゼンテーション層

### 3-1. Riverpodプロバイダーの定義
- `task_provider.dart` : タスク一覧・CRUD操作
- `filter_provider.dart` : フィルタ・ソート・検索条件の状態管理
- `priority_provider.dart` / `status_provider.dart` / `tag_provider.dart`

### 3-2. タスク一覧画面
- 検索バー
- フィルタ・ソートバー（優先度・ステータス・タグ・期限日）
- タスクカード一覧（タイトル・期限日・優先度・ステータス・タグを表示）
- 完了タスクのデフォルト非表示・表示切り替え
- タスク追加ボタン（FAB）

### 3-3. タスク追加・編集画面
- タイトル入力
- 期限日ピッカー
- 優先度セレクター
- ステータスセレクター
- タグ入力（複数入力対応）
- 保存・削除ボタン（削除は確認ダイアログあり）

### 3-4. 設定画面
- 優先度の一覧表示・追加・編集・削除・並び替え
- ステータスの一覧表示・追加・編集・削除・並び替え
- タグの一覧表示・編集・削除

---

## Step 4: 動作確認・調整

### 4-1. 各プラットフォームでの動作確認
- Android / iOS / Windows / macOS それぞれで起動確認
- UIレイアウトの崩れがないか確認

### 4-2. エッジケースの確認
- タスクが0件のとき
- タグ・優先度・ステータスを削除したとき、関連タスクへの影響
- フィルタ・ソートの組み合わせ

### 4-3. 調整・仕上げ
- UIの細部調整
- パフォーマンス確認（大量タスク時）

---

## 実装順序の理由

```
DB定義 → リポジトリ → プロバイダー → UI
```

下層から実装することで、各層を独立してテスト・確認できる。
UIを作る時点でデータの流れが確定しているため手戻りが少ない。
