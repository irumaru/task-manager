-- Create "wishes" table
CREATE TABLE "taskmanager"."wishes" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "detail" text NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "wishes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "wish_labels" table
CREATE TABLE "taskmanager"."wish_labels" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "name" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY ("id"),
  CONSTRAINT "wish_labels_user_id_name_key" UNIQUE ("user_id", "name"),
  CONSTRAINT "wish_labels_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "taskmanager"."users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
-- Create "wish_label_assignments" table
CREATE TABLE "taskmanager"."wish_label_assignments" (
  "wish_id" uuid NOT NULL,
  "wish_label_id" uuid NOT NULL,
  PRIMARY KEY ("wish_id", "wish_label_id"),
  CONSTRAINT "wish_label_assignments_wish_id_fkey" FOREIGN KEY ("wish_id") REFERENCES "taskmanager"."wishes" ("id") ON UPDATE NO ACTION ON DELETE CASCADE,
  CONSTRAINT "wish_label_assignments_wish_label_id_fkey" FOREIGN KEY ("wish_label_id") REFERENCES "taskmanager"."wish_labels" ("id") ON UPDATE NO ACTION ON DELETE CASCADE
);
