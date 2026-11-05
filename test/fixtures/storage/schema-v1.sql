CREATE TABLE "biometric_slot" ("id" INTEGER NOT NULL CHECK (id = 1), "iv" BLOB NOT NULL CHECK (length(iv) = 12), "cipher_text" BLOB NOT NULL CHECK (length(cipher_text) = 48), PRIMARY KEY ("id"));
CREATE TABLE "records" ("id" BLOB NOT NULL CHECK (length(id) = 16), "type" TEXT NOT NULL, "blob" BLOB NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id")) WITHOUT ROWID;
CREATE TABLE "unlock_state" ("id" INTEGER NOT NULL CHECK (id = 1), "failed_attempts" INTEGER NOT NULL, "last_failed_at" INTEGER NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "vault_meta" ("id" INTEGER NOT NULL CHECK (id = 1), "header" TEXT NOT NULL, PRIMARY KEY ("id"));
