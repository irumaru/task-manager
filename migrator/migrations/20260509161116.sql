-- Modify "tasks" table
ALTER TABLE "taskmanager"."tasks" ADD CONSTRAINT "tasks_importance_check" CHECK ((importance >= 1) AND (importance <= 3)), ADD CONSTRAINT "tasks_urgency_check" CHECK ((urgency >= 1) AND (urgency <= 3)), DROP COLUMN "priority_id", ADD COLUMN "importance" integer NOT NULL DEFAULT 1, ADD COLUMN "urgency" integer NOT NULL DEFAULT 1;
-- Drop "priorities" table
DROP TABLE "taskmanager"."priorities";
