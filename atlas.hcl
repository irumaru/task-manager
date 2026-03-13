env "local" {
  src = "file://schema.sql"
  url = "postgres://taskmanager:taskmanager@localhost:5432/taskmanager?sslmode=disable"
  dev = "docker://postgres/16/dev"
  migration {
    dir = "file://migrations"
  }
}
