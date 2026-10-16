package main

import "testing"

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
