# マイグレーションの実行方法

postgre...は任意のDB URLに変更する

```shell
docker run ghcr.io/irumaru/task-manager/migrator:latest migrate apply --url postgres://postgres:example@127.0.0.1:5432/taskmanager?sslmode=disable
```
