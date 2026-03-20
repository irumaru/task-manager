-- Add new schema named "taskmanager"
CREATE SCHEMA "taskmanager";
-- Create "users" table
CREATE TABLE "taskmanager"."users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "email" text NOT NULL,
  "display_name" text NOT NULL,
  "avatar_url" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "users_email_key" UNIQUE ("email")
);
-- Create "priorities" table
CREATE TABLE "taskmanager"."priorities" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "name" text NOT NULL,
  "display_order" integer NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "priorities_user_id_name_key" UNIQUE ("user_id", "name"),
  CONSTRAINT "priorities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "statuses" table
CREATE TABLE "taskmanager"."statuses" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "name" text NOT NULL,
  "display_order" integer NOT NULL DEFAULT 0,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "statuses_user_id_name_key" UNIQUE ("user_id", "name"),
  CONSTRAINT "statuses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "tags" table
CREATE TABLE "taskmanager"."tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "name" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "tags_user_id_name_key" UNIQUE ("user_id", "name"),
  CONSTRAINT "tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "tasks" table
CREATE TABLE "taskmanager"."tasks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "memo" text NULL,
  "due_date" timestamptz NULL,
  "status_id" uuid NOT NULL,
  "priority_id" uuid NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "tasks_priority_id_fkey" FOREIGN KEY ("priority_id") REFERENCES "taskmanager"."priorities" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "tasks_status_id_fkey" FOREIGN KEY ("status_id") REFERENCES "taskmanager"."statuses" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "task_tags" table
CREATE TABLE "taskmanager"."task_tags" (
  "task_id" uuid NOT NULL,
  "tag_id" uuid NOT NULL,
  PRIMARY KEY ("task_id", "tag_id"),
  CONSTRAINT "task_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "taskmanager"."tags" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "task_tags_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "taskmanager"."tasks" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
