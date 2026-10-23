package storage

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"path/filepath"
	"strings"
	"testing"
)

func TestRegisterDeviceStoresOnlyCredentialHash(t *testing.T) {
	store := openPushTestStore(t)
	ctx := context.Background()
	credential := testCredential(1)
	device, err := store.RegisterDevice(ctx, testDeviceA, "  iPhone Vendra  ", credential)
	if err != nil {
		t.Fatalf("register: %v", err)
	}
	if device.ID != testDeviceA || device.Name != "iPhone Vendra" ||
		device.CreatedAt.IsZero() || device.RevokedAt != nil {
		t.Fatalf("device = %#v", device)
	}
	var storedHash []byte
	if err := store.database.QueryRow("SELECT credential_hash FROM devices").Scan(&storedHash); err != nil {
		t.Fatalf("read hash: %v", err)
	}
	wantHash := sha256.Sum256(bytes.Repeat([]byte{1}, 32))
	if !bytes.Equal(storedHash, wantHash[:]) {
		t.Fatal("database tidak menyimpan hash SHA-256 credential")
	}
	devices, err := store.ListDevices(ctx)
	if err != nil || len(devices) != 1 || devices[0].ID != device.ID {
		t.Fatalf("devices = %#v, error = %v", devices, err)
	}
	encoded, err := json.Marshal(devices)
	if err != nil {
		t.Fatalf("encode devices: %v", err)
	}
	if bytes.Contains(encoded, []byte(credential)) ||
		bytes.Contains(encoded, []byte("credential")) || bytes.Contains(encoded, []byte("hash")) {
		t.Fatal("metadata perangkat membocorkan credential atau hash")
	}
	authenticated, err := store.AuthenticateDevice(ctx, credential)
	if err != nil || authenticated.ID != device.ID {
		t.Fatalf("authenticate = %#v, error = %v", authenticated, err)
	}
}

func TestRegisterDeviceRejectsInvalidInputWithoutWriting(t *testing.T) {
	store := openPushTestStore(t)
	for _, test := range []struct {
		name, deviceID, deviceName, credential string
		want                                   error
	}{
		{"invalid ID", "iphone", "iPhone", testCredential(1), ErrInvalidDevice},
		{"empty name", testDeviceA, " \t ", testCredential(1), ErrInvalidDeviceName},
		{"long name", testDeviceA, strings.Repeat("界", 81), testCredential(1), ErrInvalidDeviceName},
		{"control character", testDeviceA, "iPhone\nVendra", testCredential(1), ErrInvalidDeviceName},
		{"invalid utf8", testDeviceA, string([]byte{0xff}), testCredential(1), ErrInvalidDeviceName},
		{"empty credential", testDeviceA, "iPhone", "", ErrInvalidDeviceCredential},
		{"short credential", testDeviceA, "iPhone", "secret", ErrInvalidDeviceCredential},
		{"padded credential", testDeviceA, "iPhone", testCredential(1) + "=", ErrInvalidDeviceCredential},
		{"wrong alphabet", testDeviceA, "iPhone", strings.Repeat("+", 43), ErrInvalidDeviceCredential},
		{"noncanonical credential", testDeviceA, "iPhone", strings.Repeat("A", 42) + "B", ErrInvalidDeviceCredential},
	} {
		t.Run(test.name, func(t *testing.T) {
			_, err := store.RegisterDevice(context.Background(), test.deviceID, test.deviceName, test.credential)
			if !errors.Is(err, test.want) {
				t.Fatalf("error = %v, want %v", err, test.want)
			}
		})
	}
	if count := rowCount(t, store, "devices"); count != 0 {
		t.Fatalf("devices = %d, want 0", count)
	}
}

func TestDeviceIDsAreCanonicalAndCredentialsCannotBeReused(t *testing.T) {
	store := openPushTestStore(t)
	ctx := context.Background()
	device, err := store.RegisterDevice(ctx, strings.ToUpper(testDeviceA), strings.Repeat("界", 80), testCredential(1))
	if err != nil || device.ID != testDeviceA {
		t.Fatalf("register = %#v, error = %v", device, err)
	}
	for _, test := range []struct{ deviceID, credential string }{
		{testDeviceA, testCredential(2)},
		{testDeviceB, testCredential(1)},
		{testDeviceA, testCredential(1)},
	} {
		if _, err := store.RegisterDevice(ctx, test.deviceID, "Pengganti", test.credential); !errors.Is(err, ErrDeviceRegistrationConflict) {
			t.Fatalf("duplicate registration error = %v", err)
		}
	}
	authenticated, err := store.AuthenticateDevice(ctx, testCredential(1))
	if err != nil || authenticated.Name != device.Name {
		t.Fatalf("registrasi ulang mengubah perangkat: %#v, %v", authenticated, err)
	}
	if _, err := store.AuthenticateDevice(ctx, testCredential(2)); !errors.Is(err, ErrDeviceUnauthenticated) {
		t.Fatalf("credential pengganti error = %v", err)
	}
}

func TestRevokeDeviceIsDurableAndDoesNotAffectOtherDeviceOrSyncData(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "hub.sqlite")
	store, err := Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	for index, id := range []string{testDeviceA, testDeviceB} {
		if _, err := store.RegisterDevice(ctx, id, "Perangkat", testCredential(byte(index+1))); err != nil {
			t.Fatal(err)
		}
	}
	input := BootstrapInput{
		BootstrapID: testBootstrapID, DeviceID: testDeviceA,
		Bills:    []json.RawMessage{billPayload("Spotify", 4, "2026-12-25")},
		Payments: []json.RawMessage{historicalPaymentPayload(2)}, CreatedAt: "2026-10-17T00:00:00Z",
	}
	if _, err := store.Bootstrap(ctx, input); err != nil {
		t.Fatal(err)
	}
	first, err := store.RevokeDevice(ctx, strings.ToUpper(testDeviceA))
	if err != nil || first.RevokedAt == nil {
		t.Fatalf("revoke = %#v, error = %v", first, err)
	}
	second, err := store.RevokeDevice(ctx, testDeviceA)
	if err != nil || second.RevokedAt == nil || !first.RevokedAt.Equal(*second.RevokedAt) {
		t.Fatalf("retry revoke = %#v, error = %v", second, err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	reopened, err := Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	store = reopened
	for _, credential := range []string{testCredential(1), testCredential(3), "invalid"} {
		if _, err := store.AuthenticateDevice(ctx, credential); !errors.Is(err, ErrDeviceUnauthenticated) {
			t.Fatalf("credential tidak sah, error = %v", err)
		}
	}
	if device, err := store.AuthenticateDevice(ctx, testCredential(2)); err != nil || device.ID != testDeviceB {
		t.Fatalf("perangkat lain = %#v, error = %v", device, err)
	}
	for _, credential := range []string{testCredential(1), testCredential(4)} {
		if _, err := store.RegisterDevice(ctx, testDeviceA, "Aktifkan ulang", credential); !errors.Is(err, ErrDeviceRegistrationConflict) {
			t.Fatalf("registrasi ulang perangkat revoked, error = %v", err)
		}
	}
	if _, err := store.RegisterDevice(ctx, "0199e7d0-0000-7000-8000-000000000003", "Pakai token lama", testCredential(1)); !errors.Is(err, ErrDeviceRegistrationConflict) {
		t.Fatalf("reuse token revoked, error = %v", err)
	}
	devices, err := store.ListDevices(ctx)
	if err != nil || len(devices) != 2 || devices[0].RevokedAt == nil ||
		!devices[0].RevokedAt.Equal(*first.RevokedAt) || devices[1].RevokedAt != nil {
		t.Fatalf("devices setelah reopen = %#v, error = %v", devices, err)
	}
	page, err := store.Pull(ctx, 0, 100)
	if err != nil || len(page.Changes) != 2 || page.NextCursor != 2 {
		t.Fatalf("revoke mengubah data sync: %#v, error = %v", page, err)
	}
	if entityVersion(t, store, "bill", testBillID) != 4 ||
		entityVersion(t, store, "payment", testPayID) != 2 || rowCount(t, store, "operations") != 1 {
		t.Fatal("revoke mengubah snapshot atau operasi finansial")
	}
}

func TestRevokeUnknownOrInvalidDeviceDoesNotWrite(t *testing.T) {
	store := openPushTestStore(t)
	for _, test := range []struct {
		id   string
		want error
	}{
		{"invalid", ErrInvalidDevice},
		{testDeviceA, ErrDeviceNotFound},
	} {
		if _, err := store.RevokeDevice(context.Background(), test.id); !errors.Is(err, test.want) {
			t.Fatalf("error = %v, want %v", err, test.want)
		}
	}
	if count := rowCount(t, store, "devices"); count != 0 {
		t.Fatalf("devices = %d, want 0", count)
	}
}

func TestConcurrentRegistrationCannotReplaceCredential(t *testing.T) {
	store := openPushTestStore(t)
	ctx := context.Background()
	results := make(chan error, 2)
	for _, value := range []byte{1, 2} {
		go func() {
			_, err := store.RegisterDevice(ctx, testDeviceA, "iPhone", testCredential(value))
			results <- err
		}()
	}
	accepted, conflicts := 0, 0
	for range 2 {
		switch err := <-results; {
		case err == nil:
			accepted++
		case errors.Is(err, ErrDeviceRegistrationConflict):
			conflicts++
		default:
			t.Fatalf("register: %v", err)
		}
	}
	if accepted != 1 || conflicts != 1 {
		t.Fatalf("accepted = %d, conflicts = %d", accepted, conflicts)
	}
	valid := 0
	for _, value := range []byte{1, 2} {
		if _, err := store.AuthenticateDevice(ctx, testCredential(value)); err == nil {
			valid++
		}
	}
	if valid != 1 {
		t.Fatalf("credential aktif = %d, want 1", valid)
	}
}

func TestDeviceRegistryPropagatesDatabaseErrors(t *testing.T) {
	store := openPushTestStore(t)
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	if _, err := store.ListDevices(ctx); err == nil {
		t.Fatal("list menerima database tertutup")
	}
	if _, err := store.AuthenticateDevice(ctx, testCredential(1)); err == nil || errors.Is(err, ErrDeviceUnauthenticated) {
		t.Fatalf("gangguan database dianggap credential salah: %v", err)
	}
	if _, err := store.RegisterDevice(ctx, testDeviceA, "iPhone", testCredential(1)); err == nil {
		t.Fatal("register menerima database tertutup")
	}
	if _, err := store.RevokeDevice(ctx, testDeviceA); err == nil {
		t.Fatal("revoke menerima database tertutup")
	}
}

func testCredential(value byte) string {
	return base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{value}, 32))
}
