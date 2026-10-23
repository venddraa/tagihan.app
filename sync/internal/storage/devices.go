package storage

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

var (
	ErrInvalidDeviceName          = errors.New("nama perangkat harus berisi 1–80 karakter tanpa control character")
	ErrInvalidDeviceCredential    = errors.New("credential perangkat harus berupa 32 byte base64url tanpa padding")
	ErrDeviceRegistrationConflict = errors.New("identitas atau credential perangkat sudah terdaftar")
	ErrDeviceNotFound             = errors.New("perangkat tidak ditemukan")
	ErrDeviceUnauthenticated      = errors.New("credential perangkat tidak valid atau akses telah dicabut")
)

// Device sengaja tidak menyertakan token atau hash credential.
type Device struct {
	ID        string     `json:"device_id"`
	Name      string     `json:"name"`
	CreatedAt time.Time  `json:"created_at"`
	RevokedAt *time.Time `json:"revoked_at"`
}

const deviceColumns = "device_id, name, credential_hash, created_at_ms, revoked_at_ms"

// RegisterDevice hanya untuk pemanggil tepercaya setelah persetujuan admin.
func (s *Store) RegisterDevice(
	ctx context.Context,
	deviceID, name, credential string,
) (Device, error) {
	if err := ValidateDeviceRegistration(deviceID, name, credential); err != nil {
		return Device{}, err
	}
	hash, err := hashDeviceCredential(credential)
	if err != nil {
		return Device{}, err
	}

	return s.registerDeviceHash(ctx, deviceID, name, hash, false)
}

func ValidateDeviceRegistration(deviceID, name, credential string) error {
	if !uuidV7Pattern.MatchString(deviceID) {
		return ErrInvalidDevice
	}
	if !validDeviceName(strings.TrimSpace(name)) {
		return ErrInvalidDeviceName
	}
	_, err := hashDeviceCredential(credential)
	return err
}

// RegisterDeviceHash menerima digest dari request pairing yang telah diizinkan.
// Token mentah tidak perlu ditahan selama menunggu persetujuan admin.
func (s *Store) RegisterDeviceHash(ctx context.Context, deviceID, name string, hash [sha256.Size]byte) (Device, error) {
	return s.registerDeviceHash(ctx, deviceID, name, hash, true)
}

func (s *Store) registerDeviceHash(ctx context.Context, deviceID, name string, hash [sha256.Size]byte, allowRetry bool) (Device, error) {
	if !uuidV7Pattern.MatchString(deviceID) {
		return Device{}, ErrInvalidDevice
	}
	name = strings.TrimSpace(name)
	if !validDeviceName(name) {
		return Device{}, ErrInvalidDeviceName
	}
	row := s.database.QueryRowContext(ctx,
		`INSERT INTO devices(device_id, name, credential_hash, created_at_ms)
		 VALUES (?, ?, ?, ?) ON CONFLICT DO NOTHING RETURNING `+deviceColumns,
		strings.ToLower(deviceID), name, hash[:], time.Now().UTC().UnixMilli(),
	)
	device, _, err := scanDevice(row)
	if errors.Is(err, sql.ErrNoRows) {
		if allowRetry {
			existing, storedHash, readErr := scanDevice(s.database.QueryRowContext(ctx,
				"SELECT "+deviceColumns+" FROM devices WHERE device_id = ?", strings.ToLower(deviceID)))
			if readErr == nil && existing.RevokedAt == nil && existing.Name == name && subtle.ConstantTimeCompare(storedHash, hash[:]) == 1 {
				return existing, nil
			}
			if readErr != nil && !errors.Is(readErr, sql.ErrNoRows) {
				return Device{}, fmt.Errorf("read pairing approval retry: %w", readErr)
			}
		}
		// Tidak ada upsert: retry tidak boleh mengganti token atau mengaktifkan
		// kembali perangkat yang sudah dicabut aksesnya.
		return Device{}, ErrDeviceRegistrationConflict
	}
	if err != nil {
		return Device{}, fmt.Errorf("register device: %w", err)
	}
	return device, nil
}

func (s *Store) ListDevices(ctx context.Context) ([]Device, error) {
	rows, err := s.database.QueryContext(ctx,
		"SELECT "+deviceColumns+" FROM devices ORDER BY created_at_ms, device_id",
	)
	if err != nil {
		return nil, fmt.Errorf("list devices: %w", err)
	}
	defer rows.Close()

	devices := make([]Device, 0)
	for rows.Next() {
		device, _, err := scanDevice(rows)
		if err != nil {
			return nil, fmt.Errorf("read device: %w", err)
		}
		devices = append(devices, device)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("list devices: %w", err)
	}
	return devices, nil
}

// AuthenticateDevice memvalidasi credential terhadap registry. Enforcement pada
// endpoint HTTP belum diaktifkan sampai integrasi credential Fedora tersedia.
func (s *Store) AuthenticateDevice(ctx context.Context, credential string) (Device, error) {
	hash, err := hashDeviceCredential(credential)
	if err != nil {
		return Device{}, ErrDeviceUnauthenticated
	}

	// V1 memiliki beberapa perangkat saja. Membaca hash perangkat aktif menjaga
	// pembandingan credential memakai constant-time comparison tanpa early exit.
	rows, err := s.database.QueryContext(ctx,
		"SELECT "+deviceColumns+" FROM devices WHERE revoked_at_ms IS NULL",
	)
	if err != nil {
		return Device{}, fmt.Errorf("authenticate device: %w", err)
	}
	defer rows.Close()

	var matched *Device
	for rows.Next() {
		device, storedHash, err := scanDevice(rows)
		if err != nil {
			return Device{}, fmt.Errorf("read device credential: %w", err)
		}
		if subtle.ConstantTimeCompare(storedHash, hash[:]) == 1 {
			matched = &device
		}
	}
	if err := rows.Err(); err != nil {
		return Device{}, fmt.Errorf("authenticate device: %w", err)
	}
	if matched == nil {
		return Device{}, ErrDeviceUnauthenticated
	}
	return *matched, nil
}

// RevokeDevice idempotent dan mempertahankan waktu pencabutan pertama. Clock
// perangkat tidak dipakai untuk memutuskan apakah pencabutan boleh dilakukan.
func (s *Store) RevokeDevice(ctx context.Context, deviceID string) (Device, error) {
	if !uuidV7Pattern.MatchString(deviceID) {
		return Device{}, ErrInvalidDevice
	}
	row := s.database.QueryRowContext(ctx,
		`UPDATE devices SET revoked_at_ms = COALESCE(revoked_at_ms, ?)
		 WHERE device_id = ? RETURNING `+deviceColumns,
		time.Now().UTC().UnixMilli(), strings.ToLower(deviceID),
	)
	device, _, err := scanDevice(row)
	if errors.Is(err, sql.ErrNoRows) {
		return Device{}, ErrDeviceNotFound
	}
	if err != nil {
		return Device{}, fmt.Errorf("revoke device: %w", err)
	}
	return device, nil
}

func hashDeviceCredential(credential string) ([sha256.Size]byte, error) {
	if len(credential) != base64.RawURLEncoding.EncodedLen(32) {
		return [sha256.Size]byte{}, ErrInvalidDeviceCredential
	}
	decoded, err := base64.RawURLEncoding.Strict().DecodeString(credential)
	if err != nil || len(decoded) != 32 {
		return [sha256.Size]byte{}, ErrInvalidDeviceCredential
	}
	return sha256.Sum256(decoded), nil
}

func validDeviceName(name string) bool {
	return utf8.ValidString(name) && name != "" && utf8.RuneCountInString(name) <= 80 &&
		!strings.ContainsFunc(name, unicode.IsControl)
}

func scanDevice(row interface{ Scan(...any) error }) (Device, []byte, error) {
	var device Device
	var hash []byte
	var createdAt int64
	var revokedAt sql.NullInt64
	if err := row.Scan(&device.ID, &device.Name, &hash, &createdAt, &revokedAt); err != nil {
		return Device{}, nil, err
	}
	device.CreatedAt = time.UnixMilli(createdAt).UTC()
	if revokedAt.Valid {
		value := time.UnixMilli(revokedAt.Int64).UTC()
		device.RevokedAt = &value
	}
	return device, hash, nil
}
