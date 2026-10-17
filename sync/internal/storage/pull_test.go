package storage

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
)

func TestPullReturnsOrderedPagesAfterCursor(t *testing.T) {
	store := openPushTestStore(t)
	bootstrap := BootstrapInput{
		BootstrapID: testBootstrapID,
		DeviceID:    testDeviceA,
		Bills:       []json.RawMessage{billPayload("Spotify", 4, "2026-12-25")},
		Payments:    []json.RawMessage{historicalPaymentPayload(2)},
		CreatedAt:   "2026-10-17T00:00:00Z",
	}
	if _, err := store.Bootstrap(context.Background(), bootstrap); err != nil {
		t.Fatalf("bootstrap: %v", err)
	}

	first, err := store.Pull(context.Background(), 0, 1)
	if err != nil {
		t.Fatalf("first pull: %v", err)
	}
	if len(first.Changes) != 1 || !first.HasMore || first.NextCursor != 1 {
		t.Fatalf("first page = %#v", first)
	}
	if change := first.Changes[0]; change.ServerSequence != 1 ||
		change.OperationID != testBootstrapID ||
		change.EntityType != "bill" ||
		change.EntityID != testBillID ||
		change.Version != 4 ||
		change.CreatedAt != "2026-10-17T00:00:00Z" {
		t.Errorf("first change = %#v", change)
	}
	var bill billSnapshot
	if err := json.Unmarshal(first.Changes[0].Payload, &bill); err != nil {
		t.Fatalf("decode bill payload: %v", err)
	}
	if bill.Name != "Spotify" || bill.Version != 4 {
		t.Errorf("bill payload = %#v", bill)
	}

	second, err := store.Pull(context.Background(), first.NextCursor, 1)
	if err != nil {
		t.Fatalf("second pull: %v", err)
	}
	if len(second.Changes) != 1 || second.HasMore || second.NextCursor != 2 {
		t.Fatalf("second page = %#v", second)
	}
	if change := second.Changes[0]; change.ServerSequence != 2 ||
		change.EntityType != "payment" ||
		change.EntityID != testPayID ||
		change.Version != 2 {
		t.Errorf("second change = %#v", change)
	}

	empty, err := store.Pull(context.Background(), second.NextCursor, 100)
	if err != nil {
		t.Fatalf("empty pull: %v", err)
	}
	if len(empty.Changes) != 0 || empty.HasMore || empty.NextCursor != 2 {
		t.Errorf("empty page = %#v", empty)
	}
}

func TestPullRejectsInvalidArguments(t *testing.T) {
	store := openPushTestStore(t)

	if _, err := store.Pull(context.Background(), -1, 1); !errors.Is(
		err,
		ErrInvalidCursor,
	) {
		t.Errorf("negative cursor error = %v", err)
	}
	for _, limit := range []int{0, MaxPullChanges + 1} {
		if _, err := store.Pull(context.Background(), 0, limit); !errors.Is(
			err,
			ErrInvalidPullLimit,
		) {
			t.Errorf("limit %d error = %v", limit, err)
		}
	}
}
