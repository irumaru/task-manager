# WebSocket リアルタイム同期不整合の修正計画

API サーバーが配信する WebSocket イベントを Flutter クライアントが受信できていない不具合の調査結果と修正方針。

---

## 1. 現象

ログイン中の別クライアントでタスク／ステータス／優先度／タグを変更しても、自端末の一覧に反映されない。`wish` / `wish_label` も含め、リアルタイム同期が事実上無効化されている。

## 2. 根本原因

サーバー（Go）とクライアント（Flutter）の間に **2 箇所**のミスマッチがある。

### 2.1 イベントタイプ名の不一致

サーバーは [api/internal/handler/](../api/internal/handler/) 配下の各ハンドラで、CRUD すべてを単一の `*.changed` イベントに集約して送信している。

| エンティティ | サーバー送信タイプ | クライアント購読タイプ |
| --- | --- | --- |
| task | `task.changed` | `task.created` / `task.updated` / `task.deleted` |
| status | `status.changed` | `status.created` / `status.updated` / `status.deleted` |
| priority | `priority.changed` | `priority.created` / `priority.updated` / `priority.deleted` |
| tag | `tag.changed` | `tag.created` / `tag.updated` / `tag.deleted` |
| wish | `wish.changed` | `wish.changed` ✅ |
| wish_label | `wish_label.changed` | `wish_label.changed` ✅ |

[websocket_provider.dart:21-34](../app/lib/presentation/providers/websocket_provider.dart#L21-L34) の `switch` でいずれの `case` にもヒットしないため、`task` / `status` / `priority` / `tag` 系の `invalidate` は走らない。

### 2.2 JSON ペイロードのキー名不一致

サーバー [hub.go:6-9](../api/internal/websocket/hub.go#L6-L9):

```go
type Event struct {
    Type    string `json:"type"`
    Payload any    `json:"payload"`
}
```

クライアント [websocket_client.dart:13-18](../app/lib/data/api/websocket_client.dart#L13-L18) は `json['data']` を `Map<String, dynamic>` として強制キャストしている。`data` キーは存在しないので `null` が返り、`as Map<String, dynamic>` でキャスト例外が発生する。

例外は [websocket_client.dart:52-54](../app/lib/data/api/websocket_client.dart#L52-L54) の `catch (_)` で握り潰されるため、**イベントタイプが一致している `wish.changed` / `wish_label.changed` ですらパース段階で破棄される**。

## 3. 修正方針

クライアント側を **サーバーの仕様（`*.changed` 単一イベント + `payload` キー）に揃える**。

理由:

- ペイロードの中身は現状すべて空マップ（`map[string]any{}`）であり、クライアントは `invalidate` するだけなので、タイプ名以上の情報を要求していない。
- サーバー側 5 ファイル × 各 3 箇所 ＋ ペイロード生成の追加よりも、クライアント側 2 ファイルのみで完結する。
- `*.changed` への単一化は既に `wish` / `wish_label` で先行採用されており一貫する。

将来「create と delete を区別したい」「ペイロードに ID を載せて部分更新したい」というニーズが出た時点で、サーバー側を拡張して再度検討する。

## 4. 変更内容

### 4.1 [app/lib/data/api/websocket_client.dart](../app/lib/data/api/websocket_client.dart)

- `WebSocketEvent.data` フィールドを `payload` にリネーム。
- `fromJson` で `json['payload']` を読む。`Map<String, dynamic>` でない場合（現行サーバーから送られる空マップを含む）は空マップにフォールバックして、ペイロードが未使用でもキャスト例外で全イベントが落ちないようにする。

### 4.2 [app/lib/presentation/providers/websocket_provider.dart](../app/lib/presentation/providers/websocket_provider.dart)

- `task` / `status` / `priority` / `tag` の `case` を `*.created || *.updated || *.deleted` から **`*.changed` 単一**に置き換え。`wish.changed` / `wish_label.changed` は変更なし。

## 5. 影響範囲

- 影響対象は Flutter クライアントのみ。サーバー、TypeSpec、生成コードへの変更なし。
- API スキーマ・DB スキーマに影響しないため、生成コマンド（`mise run gen`）の再実行は不要。
- `WebSocketEvent.data` は外部から参照されていない（`grep` で `app/lib` 内の参照は `websocket_client.dart` 自身のみ）ので破壊的変更にならない。

## 6. 動作確認

開発環境で flutter コマンドが実行できないため、ローカル QA は実機での手動確認を推奨。

1. `docker compose up -d` で API + DB を起動。
2. 同一アカウントで端末 A／B からログイン。
3. 端末 A でタスクを作成・更新・削除する。端末 B の一覧が自動で更新されることを確認。
4. ステータス／優先度／タグについても同様に確認。
5. wish / wish_label についても引き続き同期することを確認（リグレッションがないこと）。
