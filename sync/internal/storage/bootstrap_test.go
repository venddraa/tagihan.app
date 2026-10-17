package storage

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
)

const testBootstrapID = "0199e7d0-0000-7000-8000-000000000030"

func TestBootstrapPreservesSnapshotsAndIsIdempotent(t *testing.T) {
	store := openPushTestStore(t)
	input := BootstrapInput{
		BootstrapID: testBootstrapID,
		DeviceID:    testDeviceA,
		Bills:       []json.RawMessage{billPayload("Spotify", 4, "2026-12-25")},
		Payments:    []json.RawMessage{historicalPaymentPayload(2)},
		CreatedAt:   "2026-10-17T00:00:00Z",
	}

	first, err := store.Bootstrap(context.Background(), input)
	if err != nil {
		t.Fatalf("bootstrap: %v", err)
	}
	second, err := store.Bootstrap(context.Background(), input)
	if err != nil {
		t.Fatalf("retry bootstrap: %v", err)
	}

	if first.Status != "accepted" || second.Status != "duplicate" {
		t.Fatalf("first = %#v, second = %#v", first, second)
	}
	if len(first.ServerSequences) != 2 ||
		len(second.ServerSequences) != 2 ||
		first.ServerSequences[0] != second.ServerSequences[0] ||
		first.ServerSequences[1] != second.ServerSequences[1] {
		t.Errorf("server sequences berbeda: %#v, %#v", first, second)
	}
	if version := entityVersion(t, store, "bill", testBillID); version != 4 {
		t.Errorf("bill version = %d, want 4", version)
	}
	if version := entityVersion(t, store, "payment", testPayID); version != 2 {
		t.Errorf("payment version = %d, want 2", version)
	}
	if count := rowCount(t, store, "operations"); count != 1 {
		t.Errorf("operations = %d, want 1", count)
	}
	if count := rowCount(t, store, "changes"); count != 2 {
		t.Errorf("changes = %d, want 2", count)
	}
}

func TestBootstrapRejectsSnapshotWithMissingBillAtomically(t *testing.T) {
	store := openPushTestStore(t)
	input := BootstrapInput{
		BootstrapID: testBootstrapID,
		DeviceID:    testDeviceA,
		Payments:    []json.RawMessage{historicalPaymentPayload(1)},
		CreatedAt:   "2026-10-17T00:00:00Z",
	}

	_, err := store.Bootstrap(context.Background(), input)

	if !errors.Is(err, ErrInvalidBootstrap) {
		t.Fatalf("error = %v, want ErrInvalidBootstrap", err)
	}
	for _, table := range []string{"operations", "entity_heads", "changes"} {
		if count := rowCount(t, store, table); count != 0 {
			t.Errorf("%s = %d, want 0", table, count)
		}
	}
}

func TestBootstrapRejectsHubThatAlreadyReceivedPush(t *testing.T) {
	store := openPushTestStore(t)
	operation := billOperation(
		"0199e7d0-0000-7000-8000-000000000031",
		"bill.create",
		0,
		billPayload("Spotify", 1, "2026-10-25"),
	)
	if _, err := store.Push(
		context.Background(), testDeviceA, []PushOperation{operation},
	); err != nil {
		t.Fatalf("seed push: %v", err)
	}

	_, err := store.Bootstrap(context.Background(), BootstrapInput{
		BootstrapID: testBootstrapID,
		DeviceID:    testDeviceA,
		Bills:       []json.RawMessage{billPayload("Spotify", 1, "2026-10-25")},
		CreatedAt:   "2026-10-17T00:00:00Z",
	})

	if !errors.Is(err, ErrHubNotEmpty) {
		t.Fatalf("error = %v, want ErrHubNotEmpty", err)
	}
	if count := rowCount(t, store, "operations"); count != 1 {
		t.Errorf("operations = %d, want 1", count)
	}
}

func historicalPaymentPayload(version int) json.RawMessage {
	return mustJSON(map[string]any{
		"id":                 testPayID,
		"bill_id":            testBillID,
		"amount_minor_units": 59990,
		"currency":           "IDR",
		"due_date":           "2026-09-25",
		"paid_at":            "2026-09-20T00:00:00Z",
		"notes":              "Riwayat lama",
		"created_at":         "2026-09-20T00:00:00Z",
		"updated_at":         "2026-09-20T00:00:00Z",
		"deleted_at":         nil,
		"version":            version,
	})
}
