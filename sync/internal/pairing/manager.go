package pairing

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/auth"
	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

var (
	ErrUnauthorized   = errors.New("credential pairing tidak valid")
	ErrExpired        = errors.New("undangan atau request pairing tidak tersedia atau sudah berakhir")
	ErrConflict       = errors.New("undangan atau identitas request sudah dipakai")
	ErrInvalid        = errors.New("request pairing tidak valid")
	identifierPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
)

func validID(value string) bool { return identifierPattern.MatchString(value) }

type Registry interface {
	RegisterDeviceHash(context.Context, string, string, [32]byte) (storage.Device, error)
}

type Info struct {
	Enabled        bool   `json:"enabled"`
	HubID          string `json:"hub_id"`
	Endpoint       string `json:"endpoint"`
	Fingerprint    string `json:"certificate_sha256"`
	CertificatePEM string `json:"certificate_pem"`
}

type Invitation struct {
	ProtocolVersion int       `json:"protocol_version"`
	HubID           string    `json:"hub_id"`
	Endpoint        string    `json:"endpoint"`
	Fingerprint     string    `json:"certificate_sha256"`
	ID              string    `json:"invitation_id"`
	Token           string    `json:"invitation_token"`
	ExpiresAt       time.Time `json:"expires_at"`
}

type RequestInput struct {
	ProtocolVersion int    `json:"protocol_version"`
	InvitationID    string `json:"invitation_id"`
	RequestID       string `json:"request_id"`
	DeviceID        string `json:"device_id"`
	Name            string `json:"name"`
	Credential      string `json:"credential"`
}

type InvitationSummary struct {
	ID        string    `json:"invitation_id"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (m *Manager) ActiveInvitation() *InvitationSummary {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.invitation == nil || m.request != nil || !m.now().Before(m.invitation.ExpiresAt) {
		return nil
	}
	return &InvitationSummary{ID: m.invitation.ID, ExpiresAt: m.invitation.ExpiresAt}
}

type Request struct {
	RequestID string    `json:"request_id"`
	DeviceID  string    `json:"device_id"`
	Name      string    `json:"name"`
	Status    string    `json:"status"`
	ExpiresAt time.Time `json:"expires_at"`
}

type pendingRequest struct {
	Request
	credentialHash [32]byte
	payloadHash    [32]byte
}

// Manager menyimpan hanya satu sesi sementara; restart membatalkan sesi tersebut.
// Registry device approved tetap durable di SQLite.
type Manager struct {
	mu             sync.Mutex
	registry       Registry
	info           Info
	now            func() time.Time
	invitation     *Invitation
	invitationHash [32]byte
	request        *pendingRequest
	window         time.Time
	global         int
	perIP          map[string]int
}

func New(registry Registry, info Info) *Manager {
	return &Manager{registry: registry, info: info, now: time.Now, perIP: make(map[string]int)}
}

func (m *Manager) Info() Info { return m.info }

func (m *Manager) CreateInvitation() (Invitation, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.info.Enabled {
		return Invitation{}, ErrInvalid
	}
	if m.request != nil && m.request.Status == "approving" {
		return Invitation{}, ErrConflict
	}
	var secret [32]byte
	rand.Read(secret[:])
	// Pertahankan monotonic clock selama sesi hidup; JSON mengubahnya menjadi
	// RFC3339 untuk tampilan tanpa mengubah deadline yang dipakai manager.
	invitation := Invitation{ProtocolVersion: 1, HubID: m.info.HubID, Endpoint: m.info.Endpoint, Fingerprint: m.info.Fingerprint, ID: newID(), Token: base64.RawURLEncoding.EncodeToString(secret[:]), ExpiresAt: m.now().Add(5 * time.Minute)}
	m.invitationHash = sha256.Sum256(secret[:])
	stored := invitation
	stored.Token = ""
	m.invitation = &stored
	m.request = nil
	// Token hanya dikembalikan ke admin pada response ini; tidak disimpan manager.
	return invitation, nil
}

func (m *Manager) Submit(input RequestInput, invitationToken string) (Request, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if input.ProtocolVersion != 1 || !validID(input.RequestID) || !validID(input.InvitationID) || storage.ValidateDeviceRegistration(input.DeviceID, input.Name, input.Credential) != nil {
		return Request{}, ErrInvalid
	}
	if m.invitation == nil || input.InvitationID != m.invitation.ID || !m.now().Before(m.invitation.ExpiresAt) {
		return Request{}, ErrExpired
	}
	hash, ok := tokenHash(invitationToken)
	if !ok || subtle.ConstantTimeCompare(hash[:], m.invitationHash[:]) != 1 {
		return Request{}, ErrUnauthorized
	}
	credentialHash, _ := tokenHash(input.Credential)
	if subtle.ConstantTimeCompare(credentialHash[:], m.invitationHash[:]) == 1 {
		return Request{}, ErrInvalid
	}
	input.Credential = base64.RawURLEncoding.EncodeToString(credentialHash[:])
	input.DeviceID = strings.ToLower(input.DeviceID)
	input.Name = strings.TrimSpace(input.Name)
	canonical, _ := json.Marshal(input)
	payloadHash := sha256.Sum256(canonical)
	if previous := m.request; previous != nil {
		if previous.RequestID != input.RequestID || previous.payloadHash != payloadHash {
			return Request{}, ErrConflict
		}
		m.expireRequest()
		return previous.Request, nil
	}
	m.request = &pendingRequest{Request: Request{RequestID: input.RequestID, DeviceID: input.DeviceID, Name: input.Name, Status: "pending", ExpiresAt: m.now().Add(5 * time.Minute)}, credentialHash: credentialHash, payloadHash: payloadHash}
	return m.request.Request, nil
}

func (m *Manager) Status(requestID, credential string) (Request, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.request == nil || m.request.RequestID != requestID {
		return Request{}, ErrExpired
	}
	hash, ok := tokenHash(credential)
	if !ok || subtle.ConstantTimeCompare(hash[:], m.request.credentialHash[:]) != 1 {
		return Request{}, ErrUnauthorized
	}
	m.expireRequest()
	return m.request.Request, nil
}

// CancelRequest memerlukan bukti credential kandidat dan berbagi mutex dengan
// approval. Client tidak boleh membuang credential yang sudah mendapat akses.
func (m *Manager) CancelRequest(requestID, credential string) (Request, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.request == nil || m.request.RequestID != requestID {
		return Request{}, ErrExpired
	}
	hash, ok := tokenHash(credential)
	if !ok || subtle.ConstantTimeCompare(hash[:], m.request.credentialHash[:]) != 1 {
		return Request{}, ErrUnauthorized
	}
	m.expireRequest()
	if m.request.Status == "approved" || m.request.Status == "approving" {
		return Request{}, ErrConflict
	}
	if m.request.Status == "pending" {
		m.request.Status = "cancelled"
	}
	return m.request.Request, nil
}

func (m *Manager) Requests() []Request {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.expireRequest()
	if m.request == nil {
		return []Request{}
	}
	return []Request{m.request.Request}
}

func (m *Manager) Decide(ctx context.Context, requestID string, approve bool) (Request, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.request == nil || m.request.RequestID != requestID {
		return Request{}, ErrExpired
	}
	m.expireRequest()
	want := "rejected"
	if approve {
		want = "approved"
	}
	if m.request.Status == want {
		return m.request.Request, nil
	}
	if m.request.Status != "pending" && !(approve && m.request.Status == "approving") {
		return Request{}, ErrConflict
	}
	if approve {
		// Jika storage commit tetapi response gagal, hanya retry keputusan yang
		// sama diperbolehkan. Jangan melaporkan penolakan setelah akses aktif.
		m.request.Status = "approving"
		if _, err := m.registry.RegisterDeviceHash(ctx, m.request.DeviceID, m.request.Name, m.request.credentialHash); err != nil {
			if errors.Is(err, storage.ErrDeviceRegistrationConflict) {
				// Termasuk revoke sebelum retry approval. Tidak menghidupkan
				// credential lama dan tidak menahan sesi ambigu selamanya.
				m.request.Status = "cancelled"
				return Request{}, ErrConflict
			}
			return Request{}, err
		}
	}
	m.request.Status = want
	return m.request.Request, nil
}

func (m *Manager) Cancel(invitationID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.invitation == nil || m.invitation.ID != invitationID {
		return ErrExpired
	}
	if m.request != nil && m.request.Status == "approving" {
		return ErrConflict
	}
	m.invitation.ExpiresAt = m.now()
	if m.request != nil && m.request.Status == "pending" {
		m.request.Status = "cancelled"
	}
	return nil
}

func (m *Manager) Allow(remoteIP string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.now()
	if m.window.IsZero() || now.Sub(m.window) >= time.Minute || now.Before(m.window) {
		m.window = now
		m.global = 0
		m.perIP = make(map[string]int)
	}
	if m.global >= 120 || m.perIP[remoteIP] >= 30 || (m.perIP[remoteIP] == 0 && len(m.perIP) >= 120) {
		return false
	}
	m.global++
	m.perIP[remoteIP]++
	return true
}

func (m *Manager) expireRequest() {
	if m.request != nil && m.request.Status == "pending" && !m.now().Before(m.request.ExpiresAt) {
		m.request.Status = "expired"
	}
}

func tokenHash(token string) ([32]byte, bool) {
	if !auth.ValidToken(token) {
		return [32]byte{}, false
	}
	decoded, _ := base64.RawURLEncoding.DecodeString(token)
	return sha256.Sum256(decoded), true
}
