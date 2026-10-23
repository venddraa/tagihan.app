package pairing

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

func pairingFixture(t *testing.T) (*Manager, *storage.Store) {
	t.Helper()
	store, err := storage.Open(context.Background(), filepath.Join(t.TempDir(), "hub.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	return New(store, Info{Enabled: true, HubID: newID(), Endpoint: "https://127.0.0.1:8789", Fingerprint: strings.Repeat("a", 64)}), store
}

func inputFor(invitation Invitation) RequestInput {
	return RequestInput{ProtocolVersion: 1, InvitationID: invitation.ID, RequestID: newID(), DeviceID: newID(), Name: "iPhone", Credential: base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{1}, 32))}
}

func TestCandidateCancellationIsIdempotentAndCannotUndoApproval(t *testing.T) {
	manager, store := pairingFixture(t)
	invitation, _ := manager.CreateInvitation()
	input := inputFor(invitation)
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.CancelRequest(input.RequestID, strings.Repeat("A", 43)); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("wrong credential cancel=%v", err)
	}
	for range 2 {
		result, err := manager.CancelRequest(input.RequestID, input.Credential)
		if err != nil || result.Status != "cancelled" {
			t.Fatalf("cancel=%#v,%v", result, err)
		}
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, true); !errors.Is(err, ErrConflict) {
		t.Fatal("cancelled candidate approved", err)
	}
	if _, err := store.AuthenticateDevice(context.Background(), input.Credential); !errors.Is(err, storage.ErrDeviceUnauthenticated) {
		t.Fatal("cancel granted access", err)
	}

	invitation, _ = manager.CreateInvitation()
	input = inputFor(invitation)
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, true); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.CancelRequest(input.RequestID, input.Credential); !errors.Is(err, ErrConflict) {
		t.Fatal("approved cancelled", err)
	}
	if _, err := store.AuthenticateDevice(context.Background(), input.Credential); err != nil {
		t.Fatal("approved credential lost", err)
	}
}

func TestCandidateCancelAndApproveSerialize(t *testing.T) {
	for range 10 {
		manager, store := pairingFixture(t)
		invitation, _ := manager.CreateInvitation()
		input := inputFor(invitation)
		if _, err := manager.Submit(input, invitation.Token); err != nil {
			t.Fatal(err)
		}
		var approveErr, cancelErr error
		var group sync.WaitGroup
		group.Add(2)
		go func() {
			defer group.Done()
			_, approveErr = manager.Decide(context.Background(), input.RequestID, true)
		}()
		go func() { defer group.Done(); _, cancelErr = manager.CancelRequest(input.RequestID, input.Credential) }()
		group.Wait()
		_, authentication := store.AuthenticateDevice(context.Background(), input.Credential)
		if approveErr == nil {
			if !errors.Is(cancelErr, ErrConflict) || authentication != nil {
				t.Fatalf("approval won: cancel=%v auth=%v", cancelErr, authentication)
			}
		} else if !errors.Is(approveErr, ErrConflict) || cancelErr != nil || !errors.Is(authentication, storage.ErrDeviceUnauthenticated) {
			t.Fatalf("cancel won: approve=%v cancel=%v auth=%v", approveErr, cancelErr, authentication)
		}
	}
}

func TestPairingRequiresApprovalAndKeepsOnlyHashes(t *testing.T) {
	manager, store := pairingFixture(t)
	invitation, err := manager.CreateInvitation()
	if err != nil || invitation.Token == "" {
		t.Fatalf("invitation: %v", err)
	}
	if manager.invitation.Token != "" {
		t.Fatal("manager menahan token undangan mentah")
	}
	input := inputFor(invitation)
	first, err := manager.Submit(input, invitation.Token)
	if err != nil || first.Status != "pending" {
		t.Fatalf("submit: %#v, %v", first, err)
	}
	if _, err := store.AuthenticateDevice(context.Background(), input.Credential); !errors.Is(err, storage.ErrDeviceUnauthenticated) {
		t.Fatalf("pending dapat sync: %v", err)
	}
	retry, err := manager.Submit(input, invitation.Token)
	if err != nil || retry.RequestID != first.RequestID {
		t.Fatalf("retry: %#v,%v", retry, err)
	}
	approved, err := manager.Decide(context.Background(), first.RequestID, true)
	if err != nil || approved.Status != "approved" {
		t.Fatalf("approve: %#v,%v", approved, err)
	}
	device, err := store.AuthenticateDevice(context.Background(), input.Credential)
	if err != nil || device.ID != input.DeviceID {
		t.Fatalf("approved auth: %#v,%v", device, err)
	}
	encoded, _ := json.Marshal(manager.Requests())
	if strings.Contains(string(encoded), input.Credential) || strings.Contains(string(encoded), invitation.Token) {
		t.Fatal("metadata request membocorkan token")
	}
	if _, err := store.RevokeDevice(context.Background(), device.ID); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Decide(context.Background(), first.RequestID, true); err != nil {
		t.Fatal(err)
	}
	if _, err := store.AuthenticateDevice(context.Background(), input.Credential); !errors.Is(err, storage.ErrDeviceUnauthenticated) {
		t.Fatal("retry approval mengaktifkan token revoked")
	}
}

func TestPairingRejectsWrongTokenSecondCandidateAndChangedRetry(t *testing.T) {
	manager, _ := pairingFixture(t)
	invitation, _ := manager.CreateInvitation()
	input := inputFor(invitation)
	if _, err := manager.Submit(input, strings.Repeat("A", 43)); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("wrong invite: %v", err)
	}
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	other := input
	other.RequestID = newID()
	if _, err := manager.Submit(other, invitation.Token); !errors.Is(err, ErrConflict) {
		t.Fatalf("second candidate: %v", err)
	}
	changed := input
	changed.Name = "Different"
	if _, err := manager.Submit(changed, invitation.Token); !errors.Is(err, ErrConflict) {
		t.Fatalf("changed retry: %v", err)
	}
	if _, err := manager.Status(input.RequestID, strings.Repeat("A", 43)); !errors.Is(err, ErrUnauthorized) {
		t.Fatalf("wrong pending proof: %v", err)
	}
	if _, err := manager.Status(input.RequestID, input.Credential); err != nil {
		t.Fatal(err)
	}
}

func TestPairingExpiryRejectionCancelAndRestart(t *testing.T) {
	for _, scenario := range []string{"expired invitation", "expired request", "rejected", "cancelled", "restart", "replacement"} {
		t.Run(scenario, func(t *testing.T) {
			manager, store := pairingFixture(t)
			now := time.Date(2026, 10, 24, 0, 0, 0, 0, time.UTC)
			manager.now = func() time.Time { return now }
			invitation, _ := manager.CreateInvitation()
			input := inputFor(invitation)
			if scenario == "expired invitation" {
				now = now.Add(5 * time.Minute)
				if _, err := manager.Submit(input, invitation.Token); !errors.Is(err, ErrExpired) {
					t.Fatalf("expired invite: %v", err)
				}
				return
			}
			if _, err := manager.Submit(input, invitation.Token); err != nil {
				t.Fatal(err)
			}
			switch scenario {
			case "expired request":
				now = now.Add(5 * time.Minute)
			case "rejected":
				if _, err := manager.Decide(context.Background(), input.RequestID, false); err != nil {
					t.Fatal(err)
				}
			case "cancelled":
				if err := manager.Cancel(invitation.ID); err != nil {
					t.Fatal(err)
				}
			case "replacement":
				manager.CreateInvitation()
			case "restart":
				manager = New(store, manager.Info())
			}
			if _, err := manager.Decide(context.Background(), input.RequestID, true); err == nil {
				t.Fatal("request terminal diizinkan")
			}
			if _, err := store.AuthenticateDevice(context.Background(), input.Credential); !errors.Is(err, storage.ErrDeviceUnauthenticated) {
				t.Fatalf("request terminal mendapat akses: %v", err)
			}
		})
	}
}

func TestPairingRejectsInvalidInputAndInvitationAsPermanentToken(t *testing.T) {
	manager, _ := pairingFixture(t)
	invitation, _ := manager.CreateInvitation()
	for _, modify := range []func(*RequestInput){
		func(value *RequestInput) { value.ProtocolVersion = 2 },
		func(value *RequestInput) { value.RequestID = "bad" },
		func(value *RequestInput) { value.Name = "" },
		func(value *RequestInput) { value.Credential = invitation.Token },
	} {
		input := inputFor(invitation)
		modify(&input)
		if _, err := manager.Submit(input, invitation.Token); !errors.Is(err, ErrInvalid) {
			t.Fatalf("invalid input: %v", err)
		}
	}
}

func TestConcurrentCandidatesOnlyOneCanBeApproved(t *testing.T) {
	manager, store := pairingFixture(t)
	invitation, _ := manager.CreateInvitation()
	var wait sync.WaitGroup
	results := make(chan error, 2)
	for range 2 {
		wait.Add(1)
		go func() {
			defer wait.Done()
			_, err := manager.Submit(inputFor(invitation), invitation.Token)
			results <- err
		}()
	}
	wait.Wait()
	close(results)
	accepted := 0
	for err := range results {
		if err == nil {
			accepted++
		} else if !errors.Is(err, ErrConflict) {
			t.Fatal(err)
		}
	}
	if accepted != 1 {
		t.Fatalf("accepted=%d", accepted)
	}
	requests := manager.Requests()
	if _, err := manager.Decide(context.Background(), requests[0].RequestID, true); err != nil {
		t.Fatal(err)
	}
	devices, err := store.ListDevices(context.Background())
	if err != nil || len(devices) != 1 {
		t.Fatalf("devices=%#v,error=%v", devices, err)
	}
}

func TestPairingRateLimitUsesSourceIPAndBoundedWindow(t *testing.T) {
	manager, _ := pairingFixture(t)
	now := time.Now()
	manager.now = func() time.Time { return now }
	for range 30 {
		if !manager.Allow("192.168.1.1") {
			t.Fatal("request awal ditolak")
		}
	}
	if manager.Allow("192.168.1.1") {
		t.Fatal("rate limit per IP gagal")
	}
	for _, ip := range []string{"192.168.1.2", "192.168.1.3", "192.168.1.4"} {
		for range 30 {
			if !manager.Allow(ip) {
				t.Fatal("batas global terlalu kecil")
			}
		}
	}
	if manager.Allow("192.168.1.5") {
		t.Fatal("rate limit global gagal")
	}
	now = now.Add(time.Minute)
	if !manager.Allow("192.168.1.1") {
		t.Fatal("window tidak direset")
	}
}

type interruptedApproval struct {
	store       *storage.Store
	interrupted bool
}

func (registry *interruptedApproval) RegisterDeviceHash(ctx context.Context, id, name string, hash [32]byte) (storage.Device, error) {
	device, err := registry.store.RegisterDeviceHash(ctx, id, name, hash)
	if err == nil && !registry.interrupted {
		registry.interrupted = true
		return storage.Device{}, context.DeadlineExceeded
	}
	return device, err
}

func TestApprovalRetryRecoversCommitWithoutContradictoryRejection(t *testing.T) {
	manager, store := pairingFixture(t)
	manager.registry = &interruptedApproval{store: store}
	invitation, _ := manager.CreateInvitation()
	input := inputFor(invitation)
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, true); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("interruption=%v", err)
	}
	if manager.Requests()[0].Status != "approving" {
		t.Fatal("hasil approval ambigu tidak dipertahankan")
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, false); !errors.Is(err, ErrConflict) {
		t.Fatalf("rejection setelah commit=%v", err)
	}
	if err := manager.Cancel(invitation.ID); !errors.Is(err, ErrConflict) {
		t.Fatalf("cancel setelah commit=%v", err)
	}
	if _, err := manager.CancelRequest(input.RequestID, input.Credential); !errors.Is(err, ErrConflict) {
		t.Fatalf("candidate cancel saat approval ambigu=%v", err)
	}
	if _, err := manager.CreateInvitation(); !errors.Is(err, ErrConflict) {
		t.Fatalf("replacement setelah commit=%v", err)
	}
	result, err := manager.Decide(context.Background(), input.RequestID, true)
	if err != nil || result.Status != "approved" {
		t.Fatalf("retry=%#v,%v", result, err)
	}
	devices, err := store.ListDevices(context.Background())
	if err != nil || len(devices) != 1 {
		t.Fatalf("devices=%#v,%v", devices, err)
	}
}

func TestRevokedCredentialCannotBeReactivatedByInterruptedApproval(t *testing.T) {
	manager, store := pairingFixture(t)
	manager.registry = &interruptedApproval{store: store}
	invitation, _ := manager.CreateInvitation()
	input := inputFor(invitation)
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, true); !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	if _, err := store.RevokeDevice(context.Background(), input.DeviceID); err != nil {
		t.Fatal(err)
	}
	if _, err := manager.Decide(context.Background(), input.RequestID, true); !errors.Is(err, ErrConflict) {
		t.Fatalf("retry revoked approval=%v", err)
	}
	if manager.Requests()[0].Status != "cancelled" {
		t.Fatal("sesi tidak diakhiri setelah revoke")
	}
	if _, err := store.AuthenticateDevice(context.Background(), input.Credential); !errors.Is(err, storage.ErrDeviceUnauthenticated) {
		t.Fatal("credential revoked diaktifkan ulang")
	}
	if _, err := manager.CreateInvitation(); err != nil {
		t.Fatalf("sesi baru terhalang setelah revoke: %v", err)
	}
}
