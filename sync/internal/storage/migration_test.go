package storage

import (
	"context"
	"database/sql"
	"encoding/json"
	"path/filepath"
	"reflect"
	"testing"
)

func TestMigrateVersionOnePreservesSyncDataAndIdempotency(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "legacy.sqlite")
	legacy := openVersionOneFixture(t, path)
	input := BootstrapInput{
		BootstrapID: testBootstrapID, DeviceID: testDeviceA,
		Bills:    []json.RawMessage{billPayload("Spotify", 4, "2026-12-25")},
		Payments: []json.RawMessage{historicalPaymentPayload(2)}, CreatedAt: "2026-10-17T00:00:00Z",
	}
	if _, err := legacy.Bootstrap(ctx, input); err != nil {
		t.Fatal(err)
	}
	before, err := legacy.Pull(ctx, 0, 100)
	if err != nil {
		t.Fatal(err)
	}
	if err := legacy.Close(); err != nil {
		t.Fatal(err)
	}
	store, err := Open(ctx, path)
	if err != nil {
		t.Fatalf("migrate: %v", err)
	}
	t.Cleanup(func() { store.Close() })
	version, err := store.SchemaVersion(ctx)
	if err != nil || version != 2 {
		t.Fatalf("version = %d, error = %v", version, err)
	}
	after, err := store.Pull(ctx, 0, 100)
	if err != nil || !reflect.DeepEqual(before, after) {
		t.Fatalf("migration mengubah changes: before = %#v, after = %#v, error = %v", before, after, err)
	}
	retry, err := store.Bootstrap(ctx, input)
	if err != nil || retry.Status != "duplicate" || len(retry.ServerSequences) != 2 {
		t.Fatalf("idempotency setelah migration = %#v, error = %v", retry, err)
	}
	devices, err := store.ListDevices(ctx)
	if err != nil || len(devices) != 0 {
		t.Fatalf("perangkat lama tidak boleh otomatis dipercaya: %#v, error = %v", devices, err)
	}
	var protocolVersion string
	if err := store.database.QueryRow("SELECT value FROM hub_metadata WHERE key = 'protocol_version'").Scan(&protocolVersion); err != nil || protocolVersion != "1" {
		t.Fatalf("protocol version = %q, error = %v", protocolVersion, err)
	}
	result, err := store.Push(ctx, testDeviceA, []PushOperation{
		billOperation("0199e7d0-0000-7000-8000-000000000101", "bill.update", 4,
			billPayload("Spotify diperbarui", 5, "2026-12-25")),
	})
	if err != nil || len(result) != 1 || result[0].Status != "accepted" ||
		len(result[0].ServerSequences) != 1 || result[0].ServerSequences[0] != 3 {
		t.Fatalf("sequence setelah migration = %#v, error = %v", result, err)
	}
}

func TestMigrationFailureRollsBackSchemaVersionAndPreservesLegacyTables(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "legacy.sqlite")
	legacy := openVersionOneFixture(t, path)
	if _, err := legacy.database.Exec("CREATE TABLE devices (marker TEXT)"); err != nil {
		t.Fatal(err)
	}
	if err := legacy.Close(); err != nil {
		t.Fatal(err)
	}
	if store, err := Open(ctx, path); err == nil {
		store.Close()
		t.Fatal("migration menerima schema devices yang bertabrakan")
	}
	raw, err := sql.Open("sqlite3", path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { raw.Close() })
	var version int
	if err := raw.QueryRow("PRAGMA user_version").Scan(&version); err != nil || version != 1 {
		t.Fatalf("version setelah migration gagal = %d, error = %v", version, err)
	}
	for _, table := range []string{"operations", "changes", "entity_heads", "hub_metadata", "devices"} {
		if !tableExists(t, raw, table) {
			t.Errorf("migration menghapus tabel %q", table)
		}
	}
}

func openVersionOneFixture(t *testing.T, path string) *Store {
	t.Helper()
	raw, err := sql.Open("sqlite3", path)
	if err != nil {
		t.Fatal(err)
	}
	raw.SetMaxOpenConns(1)
	t.Cleanup(func() { raw.Close() })
	for _, statement := range schemaStatements {
		if _, err := raw.Exec(statement); err != nil {
			t.Fatalf("create v1 fixture: %v", err)
		}
	}
	if _, err := raw.Exec("PRAGMA user_version = 1"); err != nil {
		t.Fatal(err)
	}
	return &Store{database: raw}
}
