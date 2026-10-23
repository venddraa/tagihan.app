package httpapi

import (
	"crypto/tls"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/venddraa/tagihan.app/sync/internal/pairing"
)

func TestPairingHTTPRequiresTLSAdminApprovalAndDeviceCredential(t *testing.T) {
	store := authenticatedTestStore(t)
	info := pairing.Info{Enabled: true, HubID: "0199e7d0-0000-7000-8000-000000000099", Endpoint: "https://127.0.0.1:8789", Fingerprint: strings.Repeat("a", 64)}
	manager := pairing.New(store, info)
	admin, err := NewAdminWithPairing(store, testAuthToken, manager)
	if err != nil {
		t.Fatal(err)
	}
	secure := NewPairingHandler(store, manager)
	if response := apiRequest(secure, http.MethodPost, "/v1/pairing/requests", "", "{}"); response.Code != http.StatusUpgradeRequired {
		t.Fatalf("plaintext pairing status=%d", response.Code)
	}
	if response := apiRequest(admin, http.MethodPost, "/v1/admin/pairing/invitations", "", "{}"); response.Code != http.StatusUnauthorized {
		t.Fatalf("unauthorized invitation status=%d", response.Code)
	}
	response := apiRequest(admin, http.MethodPost, "/v1/admin/pairing/invitations", "Bearer "+testAuthToken, "{}")
	if response.Code != http.StatusCreated {
		t.Fatal(response.Body.String())
	}
	var created struct {
		Invitation pairing.Invitation `json:"invitation"`
	}
	if err := json.Unmarshal(response.Body.Bytes(), &created); err != nil {
		t.Fatal(err)
	}
	input := pairing.RequestInput{ProtocolVersion: 1, InvitationID: created.Invitation.ID, RequestID: "0199e7d0-0000-7000-8000-000000000088", DeviceID: otherDeviceID, Name: "iPhone", Credential: authFixtureToken(1)}
	encoded, _ := json.Marshal(input)
	for range 2 {
		response = tlsAPIRequest(secure, http.MethodPost, "/v1/pairing/requests", "Bearer "+created.Invitation.Token, string(encoded))
		if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"pending"`) {
			t.Fatalf("submit status=%d,body=%s", response.Code, response.Body.String())
		}
	}
	if response := tlsAPIRequest(secure, http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+input.Credential, ""); response.Code != http.StatusUnauthorized {
		t.Fatalf("pending dapat pull: %d", response.Code)
	}
	response = apiRequest(admin, http.MethodGet, "/v1/admin/pairing", "Bearer "+testAuthToken, "")
	if strings.Contains(response.Body.String(), created.Invitation.Token) || strings.Contains(response.Body.String(), input.Credential) {
		t.Fatal("admin metadata membocorkan token")
	}
	response = apiRequest(admin, http.MethodPost, "/v1/admin/pairing/requests/"+input.RequestID+"/approve", "Bearer "+testAuthToken, "{}")
	if response.Code != http.StatusOK {
		t.Fatal(response.Body.String())
	}
	response = tlsAPIRequest(secure, http.MethodGet, "/v1/pairing/requests/"+input.RequestID, "Bearer "+input.Credential, "")
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"approved"`) {
		t.Fatalf("approved status=%d,body=%s", response.Code, response.Body.String())
	}
	response = tlsAPIRequest(secure, http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+input.Credential, "")
	if response.Code != http.StatusOK {
		t.Fatalf("approved pull status=%d", response.Code)
	}
	// Identity endpoint memungkinkan client memverifikasi approval yang durable
	// setelah restart menghapus sesi pairing sementara.
	fresh := NewPairingHandler(store, pairing.New(store, info))
	response = tlsAPIRequest(fresh, http.MethodGet, "/v1/pairing/identity", "Bearer "+input.Credential, "")
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), info.HubID) {
		t.Fatalf("identity recovery=%d", response.Code)
	}
	for _, target := range []string{"/v1/admin/pairing", "/v1/admin/devices", "/v1/sync/bootstrap"} {
		method := http.MethodGet
		if strings.Contains(target, "bootstrap") {
			method = http.MethodPost
		}
		response = tlsAPIRequest(secure, method, target, "Bearer "+testAuthToken, "{}")
		if response.Code != http.StatusNotFound {
			t.Fatalf("admin route exposed over TLS: %s=%d", target, response.Code)
		}
	}
	response = apiRequest(admin, http.MethodPost, "/v1/admin/devices/"+otherDeviceID+"/revoke", "Bearer "+testAuthToken, "{}")
	if response.Code != http.StatusOK {
		t.Fatal(response.Body.String())
	}
	response = tlsAPIRequest(fresh, http.MethodGet, "/v1/pairing/identity", "Bearer "+input.Credential, "")
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("revoked identity recovery=%d", response.Code)
	}
}

func TestCandidateCancelEndpointRequiresProofAndPreservesApproval(t *testing.T) {
	store := authenticatedTestStore(t)
	manager := pairing.New(store, pairing.Info{Enabled: true})
	invitation, err := manager.CreateInvitation()
	if err != nil {
		t.Fatal(err)
	}
	input := pairing.RequestInput{ProtocolVersion: 1, InvitationID: invitation.ID, RequestID: "0199e7d0-0000-7000-8000-000000000088", DeviceID: otherDeviceID, Name: "iPhone", Credential: authFixtureToken(1)}
	if _, err := manager.Submit(input, invitation.Token); err != nil {
		t.Fatal(err)
	}
	handler := NewPairingHandler(store, manager)
	path := "/v1/pairing/requests/" + input.RequestID + "/cancel"
	if response := tlsAPIRequest(handler, http.MethodPost, path, "Bearer "+invitation.Token, "{}"); response.Code != http.StatusUnauthorized {
		t.Fatal("invitation may cancel candidate", response.Code)
	}
	for range 2 {
		response := tlsAPIRequest(handler, http.MethodPost, path, "Bearer "+input.Credential, "{}")
		if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), `"cancelled"`) {
			t.Fatal(response.Code, response.Body.String())
		}
	}
}

func TestPairingRateLimitDoesNotTrustForwardedHeaders(t *testing.T) {
	store := authenticatedTestStore(t)
	manager := pairing.New(store, pairing.Info{Enabled: true})
	handler := NewPairingHandler(store, manager)
	for count := 0; count < 31; count++ {
		request := httptest.NewRequest(http.MethodGet, "/v1/pairing/requests/unknown", nil)
		request.TLS = &tls.ConnectionState{}
		request.Header.Set("X-Forwarded-For", strings.Repeat("a", count+1))
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, request)
		if count < 30 && response.Code == http.StatusTooManyRequests {
			t.Fatal("rate limit terlalu awal")
		}
		if count == 30 && response.Code != http.StatusTooManyRequests {
			t.Fatalf("forwarded header melewati rate limit: %d", response.Code)
		}
	}
}

func tlsAPIRequest(handler http.Handler, method, target, credential, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(method, target, strings.NewReader(body))
	request.TLS = &tls.ConnectionState{}
	request.Header.Set("Content-Type", "application/json")
	if credential != "" {
		request.Header.Set("Authorization", credential)
	}
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}
