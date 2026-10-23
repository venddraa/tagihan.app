package pairing

import (
	"crypto/sha256"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestIdentityPersistsAndRejectsUnsafeFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "identity", "tls.json")
	first, err := LoadIdentity(path)
	if err != nil {
		t.Fatal(err)
	}
	second, err := LoadIdentity(path)
	if err != nil || first.HubID != second.HubID || first.Fingerprint() != second.Fingerprint() {
		t.Fatalf("identity berubah: %v", err)
	}
	if err := os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadIdentity(path); err == nil {
		t.Fatal("identity publik diterima")
	}
}

func TestTLSHandshakeValidatesFingerprintInMemory(t *testing.T) {
	identity, err := newIdentity()
	if err != nil {
		t.Fatal(err)
	}
	configuration, err := identity.TLSConfig()
	if err != nil {
		t.Fatal(err)
	}
	if configuration.MinVersion != tls.VersionTLS13 {
		t.Fatal("TLS 1.3 tidak diwajibkan")
	}
	for _, correct := range []bool{true, false} {
		serverSide, clientSide := net.Pipe()
		serverSide.SetDeadline(time.Now().Add(3 * time.Second))
		clientSide.SetDeadline(time.Now().Add(3 * time.Second))
		server := tls.Server(serverSide, configuration)
		client := tls.Client(clientSide, &tls.Config{MinVersion: tls.VersionTLS13, InsecureSkipVerify: true, VerifyConnection: func(state tls.ConnectionState) error {
			hash := sha256.Sum256(state.PeerCertificates[0].Raw)
			if !correct || hex.EncodeToString(hash[:]) != identity.Fingerprint() {
				return errors.New("pin mismatch")
			}
			return nil
		}})
		finished := make(chan error, 1)
		go func() { finished <- server.Handshake() }()
		err := client.Handshake()
		serverSide.Close()
		clientSide.Close()
		<-finished
		if correct && err != nil {
			t.Fatalf("valid pin handshake: %v", err)
		}
		if !correct && err == nil {
			t.Fatal("wrong pin accepted")
		}
	}
}
