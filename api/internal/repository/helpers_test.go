package repository_test

import "github.com/google/uuid"

// nonExistentUUID is a valid UUID that will never match any DB record.
var nonExistentUUID = uuid.MustParse("00000000-0000-0000-0000-000000000001")
