package auth

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLocalTokenIsSecureAndStable(t *testing.T) {
	path := filepath.Join(t.TempDir(), "auth", "admin.token")
	first, err := LoadOrCreateLocalToken(path)
	if err != nil || !ValidToken(first) {
		t.Fatalf("create token: %v", err)
	}
	second, err := LoadOrCreateLocalToken(path)
	if err != nil || !EqualTokens(first, second) {
		t.Fatalf("token berubah setelah dibuka ulang: %v", err)
	}
	info, err := os.Stat(path)
	if err != nil || info.Mode().Perm() != 0o600 {
		t.Fatalf("permission credential: %v", err)
	}
	directory, err := os.Stat(filepath.Dir(path))
	if err != nil || directory.Mode().Perm() != 0o700 {
		t.Fatalf("permission directory: %v", err)
	}
}

func TestLocalTokenRejectsUnsafeExistingFileWithoutOverwriting(t *testing.T) {
	for _, test := range []struct {
		name, contents string
		mode           os.FileMode
	}{
		{"public file", strings.Repeat("A", 43), 0o644},
		{"invalid token", "broken", 0o600},
		{"invalid encoding", strings.Repeat("!", 43), 0o600},
	} {
		t.Run(test.name, func(t *testing.T) {
			directory := filepath.Join(t.TempDir(), "auth")
			if err := os.Mkdir(directory, 0o700); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(directory, "admin.token")
			if err := os.WriteFile(path, []byte(test.contents), test.mode); err != nil {
				t.Fatal(err)
			}
			if _, err := LoadOrCreateLocalToken(path); err == nil {
				t.Fatal("credential tidak aman diterima")
			}
			contents, err := os.ReadFile(path)
			if err != nil || string(contents) != test.contents {
				t.Fatalf("file credential ditimpa: %v", err)
			}
		})
	}
}

func TestLocalTokenRejectsSymlinkAndPublicDirectory(t *testing.T) {
	directory := filepath.Join(t.TempDir(), "auth")
	if err := os.Mkdir(directory, 0o700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(directory, "admin.token")
	target := filepath.Join(directory, "target")
	if err := os.WriteFile(target, []byte(strings.Repeat("A", 43)), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, path); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadOrCreateLocalToken(path); err == nil {
		t.Fatal("symlink credential diterima")
	}
	if err := os.Chmod(directory, 0o755); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadOrCreateLocalToken(target); err == nil {
		t.Fatal("direktori publik diterima")
	}
}

func TestConcurrentLocalTokenCreationReturnsOneCredential(t *testing.T) {
	path := filepath.Join(t.TempDir(), "auth", "admin.token")
	results := make(chan string, 8)
	errors := make(chan error, 8)
	for range 8 {
		go func() {
			token, err := LoadOrCreateLocalToken(path)
			results <- token
			errors <- err
		}()
	}
	var expected string
	for range 8 {
		token := <-results
		if err := <-errors; err != nil {
			t.Fatal(err)
		}
		if expected == "" {
			expected = token
		}
		if !EqualTokens(expected, token) {
			t.Fatal("pembuatan bersamaan menghasilkan credential berbeda")
		}
	}
}

func TestTokenComparisonRejectsInvalidValues(t *testing.T) {
	valid := strings.Repeat("A", 43)
	for _, value := range []string{"", "secret", strings.Repeat("B", 43), valid + "=", strings.Repeat("A", 42) + "B"} {
		if EqualTokens(valid, value) {
			t.Fatal("token salah diterima")
		}
	}
}
