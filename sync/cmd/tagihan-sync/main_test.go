package main

import "testing"

func TestPairingListenerRequiresExplicitPrivateAddress(t *testing.T) {
	for _, address := range []string{"127.0.0.1:8789", "192.168.1.2:8789", "10.0.0.1:8789", "[fd00::1]:8789"} {
		if err := requirePairingAddress(address); err != nil {
			t.Errorf("%s: %v", address, err)
		}
	}
	for _, address := range []string{"0.0.0.0:8789", "[::]:8789", "8.8.8.8:8789", "localhost:8789", "192.168.1.2:0", "192.168.1.2:99999"} {
		if err := requirePairingAddress(address); err == nil {
			t.Errorf("alamat %s diterima", address)
		}
	}
}

func TestRequireLoopback(t *testing.T) {
	t.Parallel()

	for _, address := range []string{
		"127.0.0.1:8787",
		"[::1]:8787",
		"localhost:8787",
	} {
		if err := requireLoopback(address); err != nil {
			t.Errorf("requireLoopback(%q): %v", address, err)
		}
	}
}

func TestRequireLoopbackRejectsLAN(t *testing.T) {
	t.Parallel()

	for _, address := range []string{"0.0.0.0:8787", "192.168.1.2:8787"} {
		if err := requireLoopback(address); err == nil {
			t.Errorf("requireLoopback(%q) menerima alamat LAN", address)
		}
	}
}

func TestDefaultDatabasePathUsesXDGDataHome(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", "/tmp/tagihan-data")

	path, err := defaultDatabasePath()
	if err != nil {
		t.Fatalf("defaultDatabasePath(): %v", err)
	}
	if path != "/tmp/tagihan-data/tagihan-vendra/sync/hub.sqlite" {
		t.Errorf("path = %q", path)
	}
}
