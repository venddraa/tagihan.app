package storage

import (
	"context"
	"encoding/json"
	"path/filepath"
	"testing"
)

const (
	testDeviceA = "0199e7d0-0000-7000-8000-000000000001"
	testDeviceB = "0199e7d0-0000-7000-8000-000000000002"
	testBillID  = "0199e7d0-0000-7000-8000-000000000010"
	testPayID   = "0199e7d0-0000-7000-8000-000000000020"
)

func TestPushAppliesBillOperationsInOrder(t *testing.T) {
	store := openPushTestStore(t)
	operations := []PushOperation{
		billOperation(
			"0199e7d0-0000-7000-8000-000000000101",
			"bill.create",
			0,
			billPayload("Spotify", 1, "2026-10-25"),
		),
		billOperation(
			"0199e7d0-0000-7000-8000-000000000102",
			"bill.update",
			1,
			billPayload("Spotify Premium", 2, "2026-10-25"),
		),
	}

	results, err := store.Push(context.Background(), testDeviceA, operations)
	if err != nil {
		t.Fatalf("push bills: %v", err)
	}
	if len(results) != 2 ||
		results[0].Status != "accepted" ||
		results[1].Status != "accepted" {
		t.Fatalf("results = %#v", results)
	}
	if results[0].ServerSequences[0] != 1 ||
		results[1].ServerSequences[0] != 2 {
		t.Errorf("server sequences = %#v", results)
	}
	if version := entityVersion(t, store, "bill", testBillID); version != 2 {
		t.Errorf("bill version = %d, want 2", version)
	}
	if count := rowCount(t, store, "changes"); count != 2 {
		t.Errorf("changes = %d, want 2", count)
	}
}

func TestPushRetryDoesNotDuplicateAcceptedOperation(t *testing.T) {
	store := openPushTestStore(t)
	operation := billOperation(
		"0199e7d0-0000-7000-8000-000000000103",
		"bill.create",
		0,
		billPayload("Spotify", 1, "2026-10-25"),
	)

	first, err := store.Push(
		context.Background(),
		testDeviceA,
		[]PushOperation{operation},
	)
	if err != nil {
		t.Fatalf("first push: %v", err)
	}
	second, err := store.Push(
		context.Background(),
		testDeviceA,
		[]PushOperation{operation},
	)
	if err != nil {
		t.Fatalf("retry push: %v", err)
	}

	if first[0].Status != "accepted" || second[0].Status != "duplicate" {
		t.Fatalf("first = %#v, second = %#v", first, second)
	}
	if len(second[0].ServerSequences) != 1 ||
		second[0].ServerSequences[0] != first[0].ServerSequences[0] {
		t.Errorf("retry sequences = %#v", second[0].ServerSequences)
	}
	if count := rowCount(t, store, "operations"); count != 1 {
		t.Errorf("operations = %d, want 1", count)
	}
	if count := rowCount(t, store, "changes"); count != 1 {
		t.Errorf("changes = %d, want 1", count)
	}
}

func TestPushDetectsConflictAndBlocksDependentOperation(t *testing.T) {
	store := openPushTestStore(t)
	seed := []PushOperation{
		billOperation(
			"0199e7d0-0000-7000-8000-000000000104",
			"bill.create",
			0,
			billPayload("Spotify", 1, "2026-10-25"),
		),
		billOperation(
			"0199e7d0-0000-7000-8000-000000000105",
			"bill.update",
			1,
			billPayload("Perubahan Fedora", 2, "2026-10-25"),
		),
	}
	if _, err := store.Push(context.Background(), testDeviceA, seed); err != nil {
		t.Fatalf("seed bill: %v", err)
	}
	conflicting := billOperation(
		"0199e7d0-0000-7000-8000-000000000106",
		"bill.update",
		1,
		billPayload("Perubahan iPhone", 2, "2026-10-25"),
	)
	dependent := billOperation(
		"0199e7d0-0000-7000-8000-000000000107",
		"bill.update",
		2,
		billPayload("Edit setelah conflict", 3, "2026-10-25"),
	)

	results, err := store.Push(
		context.Background(),
		testDeviceB,
		[]PushOperation{conflicting, dependent},
	)
	if err != nil {
		t.Fatalf("push conflicts: %v", err)
	}
	if results[0].Status != "conflict" ||
		results[0].ErrorCode != "version_conflict" ||
		results[1].Status != "conflict" ||
		results[1].ErrorCode != "prior_operation_unresolved" {
		t.Fatalf("results = %#v", results)
	}
	if version := entityVersion(t, store, "bill", testBillID); version != 2 {
		t.Errorf("bill version = %d, want 2", version)
	}
	if count := rowCount(t, store, "changes"); count != 2 {
		t.Errorf("changes = %d, want 2", count)
	}
}

func TestPushRecordsPaymentAndBillChangeAtomically(t *testing.T) {
	store := openPushTestStore(t)
	create := billOperation(
		"0199e7d0-0000-7000-8000-000000000108",
		"bill.create",
		0,
		billPayload("Spotify", 1, "2026-10-25"),
	)
	if _, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{create},
	); err != nil {
		t.Fatalf("create bill: %v", err)
	}
	paymentOperation := PushOperation{
		OperationID:   "0199e7d0-0000-7000-8000-000000000109",
		EntityType:    "payment",
		EntityID:      testPayID,
		OperationType: "payment.record",
		BaseVersion:   0,
		Payload: paymentPayload(
			billPayload("Spotify", 2, "2026-11-25"),
		),
		CreatedAt: "2026-10-17T00:00:00Z",
	}

	results, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{paymentOperation},
	)
	if err != nil {
		t.Fatalf("record payment: %v", err)
	}
	if results[0].Status != "accepted" ||
		len(results[0].ServerSequences) != 2 {
		t.Fatalf("result = %#v", results[0])
	}
	if version := entityVersion(t, store, "payment", testPayID); version != 1 {
		t.Errorf("payment version = %d, want 1", version)
	}
	if version := entityVersion(t, store, "bill", testBillID); version != 2 {
		t.Errorf("bill version = %d, want 2", version)
	}
	if count := rowCount(t, store, "changes"); count != 3 {
		t.Errorf("changes = %d, want 3", count)
	}
}

func TestPushRejectsPaymentWithoutPartialWrite(t *testing.T) {
	store := openPushTestStore(t)
	create := billOperation(
		"0199e7d0-0000-7000-8000-000000000111",
		"bill.create",
		0,
		billPayload("Spotify", 1, "2026-10-25"),
	)
	if _, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{create},
	); err != nil {
		t.Fatalf("create bill: %v", err)
	}
	invalidPayment := PushOperation{
		OperationID:   "0199e7d0-0000-7000-8000-000000000112",
		EntityType:    "payment",
		EntityID:      testPayID,
		OperationType: "payment.record",
		BaseVersion:   0,
		Payload: paymentPayload(
			billPayload("Spotify", 3, "2026-11-25"),
		),
		CreatedAt: "2026-10-17T00:00:00Z",
	}

	results, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{invalidPayment},
	)
	if err != nil {
		t.Fatalf("push invalid payment: %v", err)
	}
	if results[0].Status != "rejected" ||
		results[0].ErrorCode != "invalid_version" {
		t.Fatalf("result = %#v", results[0])
	}
	if entityExists(t, store, "payment", testPayID) {
		t.Fatal("payment tersimpan meski operation ditolak")
	}
	if version := entityVersion(t, store, "bill", testBillID); version != 1 {
		t.Errorf("bill version = %d, want 1", version)
	}
	if count := rowCount(t, store, "changes"); count != 1 {
		t.Errorf("changes = %d, want 1", count)
	}
}

func TestPushRejectsChangedPayloadForExistingOperationID(t *testing.T) {
	store := openPushTestStore(t)
	operation := billOperation(
		"0199e7d0-0000-7000-8000-000000000110",
		"bill.create",
		0,
		billPayload("Spotify", 1, "2026-10-25"),
	)
	if _, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{operation},
	); err != nil {
		t.Fatalf("first push: %v", err)
	}
	operation.Payload = billPayload("Payload berbeda", 1, "2026-10-25")

	results, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{operation},
	)
	if err != nil {
		t.Fatalf("second push: %v", err)
	}
	if results[0].Status != "rejected" ||
		results[0].ErrorCode != "operation_id_reused" {
		t.Fatalf("result = %#v", results[0])
	}
	if count := rowCount(t, store, "changes"); count != 1 {
		t.Errorf("changes = %d, want 1", count)
	}
}

func openPushTestStore(t *testing.T) *Store {
	t.Helper()
	store, err := Open(
		context.Background(),
		filepath.Join(t.TempDir(), "hub.sqlite"),
	)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() {
		if err := store.Close(); err != nil {
			t.Errorf("close store: %v", err)
		}
	})
	return store
}

func billOperation(
	operationID string,
	operationType string,
	baseVersion int,
	payload json.RawMessage,
) PushOperation {
	return PushOperation{
		OperationID:   operationID,
		EntityType:    "bill",
		EntityID:      testBillID,
		OperationType: operationType,
		BaseVersion:   baseVersion,
		Payload:       payload,
		CreatedAt:     "2026-10-17T00:00:00Z",
	}
}

func billPayload(name string, version int, nextDueDate string) json.RawMessage {
	return mustJSON(map[string]any{
		"id":                 testBillID,
		"name":               name,
		"category":           "Hiburan",
		"amount_minor_units": 59990,
		"currency":           "IDR",
		"billing_cycle":      "monthly",
		"next_due_date":      nextDueDate,
		"start_date":         "2026-01-25",
		"status":             "active",
		"notes":              nil,
		"created_at":         "2026-10-01T00:00:00Z",
		"updated_at":         "2026-10-17T00:00:00Z",
		"deleted_at":         nil,
		"version":            version,
	})
}

func paymentPayload(bill json.RawMessage) json.RawMessage {
	var billValue any
	if err := json.Unmarshal(bill, &billValue); err != nil {
		panic(err)
	}
	return mustJSON(map[string]any{
		"payment": map[string]any{
			"id":                 testPayID,
			"bill_id":            testBillID,
			"amount_minor_units": 59990,
			"currency":           "IDR",
			"due_date":           "2026-10-25",
			"paid_at":            "2026-10-17T00:00:00Z",
			"notes":              nil,
			"created_at":         "2026-10-17T00:00:00Z",
			"updated_at":         "2026-10-17T00:00:00Z",
			"deleted_at":         nil,
			"version":            1,
		},
		"bill":              billValue,
		"bill_base_version": 1,
	})
}

func mustJSON(value any) json.RawMessage {
	encoded, err := json.Marshal(value)
	if err != nil {
		panic(err)
	}
	return encoded
}

func entityVersion(t *testing.T, store *Store, entityType, entityID string) int {
	t.Helper()
	var version int
	if err := store.database.QueryRow(
		`SELECT version FROM entity_heads
		 WHERE entity_type = ? AND entity_id = ?`,
		entityType,
		entityID,
	).Scan(&version); err != nil {
		t.Fatalf("read entity version: %v", err)
	}
	return version
}

func entityExists(t *testing.T, store *Store, entityType, entityID string) bool {
	t.Helper()
	var count int
	if err := store.database.QueryRow(
		`SELECT COUNT(*) FROM entity_heads
		 WHERE entity_type = ? AND entity_id = ?`,
		entityType,
		entityID,
	).Scan(&count); err != nil {
		t.Fatalf("find entity: %v", err)
	}
	return count == 1
}

func rowCount(t *testing.T, store *Store, table string) int {
	t.Helper()
	var count int
	if err := store.database.QueryRow("SELECT COUNT(*) FROM " + table).Scan(
		&count,
	); err != nil {
		t.Fatalf("count %s: %v", table, err)
	}
	return count
}
