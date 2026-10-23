package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
)

func ValidToken(token string) bool {
	if len(token) != base64.RawURLEncoding.EncodedLen(32) {
		return false
	}
	decoded, err := base64.RawURLEncoding.Strict().DecodeString(token)
	return err == nil && len(decoded) == 32
}

func EqualTokens(first, second string) bool {
	if !ValidToken(first) || !ValidToken(second) {
		return false
	}
	firstHash := sha256.Sum256([]byte(first))
	secondHash := sha256.Sum256([]byte(second))
	return subtle.ConstantTimeCompare(firstHash[:], secondHash[:]) == 1
}

// LoadOrCreateLocalToken tidak menimpa credential yang sudah ada. File baru
// dipublikasikan atomik dengan hard link agar pembaca tidak melihat token parsial.
func LoadOrCreateLocalToken(path string) (string, error) {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return "", fmt.Errorf("create credential directory: %w", err)
	}
	info, err := os.Stat(directory)
	if err != nil || info.Mode().Perm()&0o077 != 0 {
		return "", errors.New("direktori credential admin harus berizin 0700")
	}
	if token, err := readLocalToken(path); !errors.Is(err, os.ErrNotExist) {
		return token, err
	}
	secret := make([]byte, 32)
	rand.Read(secret)
	token := base64.RawURLEncoding.EncodeToString(secret)
	file, err := os.CreateTemp(directory, ".admin-token-*")
	if err != nil {
		return "", fmt.Errorf("create temporary credential: %w", err)
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if _, err := file.WriteString(token); err != nil {
		return "", fmt.Errorf("write credential: %w", err)
	}
	if err := file.Sync(); err != nil {
		return "", fmt.Errorf("sync credential: %w", err)
	}
	if err := file.Close(); err != nil {
		return "", fmt.Errorf("close credential: %w", err)
	}
	if err := os.Link(file.Name(), path); err != nil && !errors.Is(err, os.ErrExist) {
		return "", fmt.Errorf("publish credential: %w", err)
	}
	return readLocalToken(path)
}

func readLocalToken(path string) (string, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return "", err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm() != 0o600 || info.Size() != 43 {
		return "", errors.New("file credential admin harus regular, berizin 0600, dan berisi token yang valid")
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("read credential: %w", err)
	}
	if !ValidToken(string(contents)) {
		return "", errors.New("isi credential admin tidak valid")
	}
	return string(contents), nil
}
