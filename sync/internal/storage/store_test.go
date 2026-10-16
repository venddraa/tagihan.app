package storage

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"testing"
)

func TestOpenCreatesSecureVersionedDatabase(t *testing.T) {
	t.Parallel()

	databasePath := filepath.Join(t.TempDir(), "nested", "hub.sqlite")
	store, err := Open(context.Background(), databasePath)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() {
		if err := store.Close(); err != nil {
			t.Errorf("close store: %v", err)
		}
	})

	version, err := store.SchemaVersion(context.Background())
	if err != nil {
		t.Fatalf("read schema version: %v", err)
	}
	if version != SchemaVersion {
		t.Fatalf("schema version = %d, want %d", version, SchemaVersion)
	}

	for _, table := range []string{
		"operations",
		"entity_heads",
		"changes",
		"hub_metadata",
	} {
		if !tableExists(t, store.database, table) {
			t.Errorf("table %q tidak dibuat", table)
		}
	}

	info, err := os.Stat(databasePath)
	if err != nil {
		t.Fatalf("stat database: %v", err)
	}
	if permission := info.Mode().Perm(); permission != 0o600 {
		t.Errorf("database permission = %o, want 600", permission)
	}

	var foreignKeys int
	if err := store.database.QueryRow("PRAGMA foreign_keys").Scan(
		&foreignKeys,
	); err != nil {
		t.Fatalf("read foreign_keys: %v", err)
	}
	if foreignKeys != 1 {
		t.Errorf("foreign_keys = %d, want 1", foreignKeys)
	}

	var journalMode string
	if err := store.database.QueryRow("PRAGMA journal_mode").Scan(
		&journalMode,
	); err != nil {
		t.Fatalf("read journal_mode: %v", err)
	}
	if journalMode != "wal" {
		t.Errorf("journal_mode = %q, want wal", journalMode)
	}
}

func TestOpenRejectsNewerSchema(t *testing.T) {
	t.Parallel()

	databasePath := filepath.Join(t.TempDir(), "future.sqlite")
	database, err := sql.Open("sqlite3", databasePath)
	if err != nil {
		t.Fatalf("open raw database: %v", err)
	}
	if _, err := database.Exec("PRAGMA user_version = 99"); err != nil {
		t.Fatalf("set future schema: %v", err)
	}
	if err := database.Close(); err != nil {
		t.Fatalf("close raw database: %v", err)
	}

	store, err := Open(context.Background(), databasePath)
	if err == nil {
		store.Close()
		t.Fatal("Open() menerima schema yang lebih baru")
	}
}

func tableExists(t *testing.T, database *sql.DB, name string) bool {
	t.Helper()

	var count int
	if err := database.QueryRow(
		`SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?`,
		name,
	).Scan(&count); err != nil {
		t.Fatalf("find table %q: %v", name, err)
	}
	return count == 1
}
