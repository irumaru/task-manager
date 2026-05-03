-- Modify "priorities" table
ALTER TABLE "taskmanager"."priorities" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "statuses" table
ALTER TABLE "taskmanager"."statuses" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "tags" table
ALTER TABLE "taskmanager"."tags" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "tasks" table
ALTER TABLE "taskmanager"."tasks" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "users" table
ALTER TABLE "taskmanager"."users" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "wish_labels" table
ALTER TABLE "taskmanager"."wish_labels" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
-- Modify "wishes" table
ALTER TABLE "taskmanager"."wishes" ALTER COLUMN "id" DROP DEFAULT, ALTER COLUMN "created_at" DROP DEFAULT, ALTER COLUMN "updated_at" DROP DEFAULT;
