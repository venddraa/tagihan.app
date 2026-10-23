package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

const otherDeviceID = "0199e7d0-0000-7000-8000-000000000002"

func TestSyncAuthenticationAndIdentity(t *testing.T) {
	store := authenticatedTestStore(t)
	token := authFixtureToken(1)
	if _, err := store.RegisterDevice(context.Background(), testAuthDeviceID, "Fedora", token); err != nil {
		t.Fatal(err)
	}
	handler := New(store)
	for _, header := range []string{"", "Basic abc", "Bearer invalid", "Bearer " + authFixtureToken(2), "Bearer  " + token} {
		for _, target := range []string{"/v1/sync/pull?after=0", "/v1/sync/push"} {
			response := apiRequest(handler, http.MethodPost, target, header, "{}")
			if strings.Contains(target, "pull") {
				response = apiRequest(handler, http.MethodGet, target, header, "")
			}
			if response.Code != http.StatusUnauthorized {
				t.Fatalf("unauthenticated request status = %d", response.Code)
			}
		}
	}
	response := apiRequest(handler, http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+token, "")
	if response.Code != http.StatusOK {
		t.Fatalf("authorized pull status = %d, body = %s", response.Code, response.Body.String())
	}
	response = apiRequest(handler, http.MethodPost, "/v1/sync/push", "Bearer "+token,
		`{"protocol_version":1,"device_id":"`+otherDeviceID+`","operations":[{}]}`)
	if response.Code != http.StatusForbidden {
		t.Fatalf("spoofed device status = %d", response.Code)
	}
	if _, err := store.RevokeDevice(context.Background(), testAuthDeviceID); err != nil {
		t.Fatal(err)
	}
	response = apiRequest(handler, http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+token, "")
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("revoked credential status = %d", response.Code)
	}
}

func TestAdminRoutesAreIsolatedAndBootstrapIsProtected(t *testing.T) {
	store := authenticatedTestStore(t)
	deviceToken := authFixtureToken(1)
	if _, err := store.RegisterDevice(context.Background(), testAuthDeviceID, "Fedora", deviceToken); err != nil {
		t.Fatal(err)
	}
	admin, err := NewAdmin(store, testAuthToken)
	if err != nil {
		t.Fatal(err)
	}
	for _, target := range []string{"/v1/admin/devices", "/v1/sync/bootstrap"} {
		method := http.MethodGet
		if strings.Contains(target, "bootstrap") {
			method = http.MethodPost
		}
		if response := apiRequest(New(store), method, target, "Bearer "+deviceToken, "{}"); response.Code != http.StatusNotFound {
			t.Fatalf("admin route tersedia pada sync listener: %d", response.Code)
		}
		for _, credential := range []string{"", "Bearer " + deviceToken} {
			if response := apiRequest(admin, method, target, credential, "{}"); response.Code != http.StatusUnauthorized {
				t.Fatalf("admin tanpa credential admin: %d", response.Code)
			}
		}
	}
	if response := apiRequest(New(store), http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+testAuthToken, ""); response.Code != http.StatusUnauthorized {
		t.Fatalf("credential admin diterima sebagai token sync: %d", response.Code)
	}
	if response := apiRequest(New(store), http.MethodGet, "/v1/health", "", ""); response.Code != http.StatusOK {
		t.Fatalf("health check memerlukan token: %d", response.Code)
	}
	if _, err := NewAdmin(store, ""); err == nil {
		t.Fatal("admin handler menerima token kosong")
	}
}

func TestAdminRegistrationRetryRevokeAndRedaction(t *testing.T) {
	store := authenticatedTestStore(t)
	admin, err := NewAdmin(store, testAuthToken)
	if err != nil {
		t.Fatal(err)
	}
	header := "Bearer " + testAuthToken
	token := authFixtureToken(1)
	body := registrationBody(testAuthDeviceID, "Fedora", token)
	for _, want := range []int{http.StatusCreated, http.StatusOK} {
		response := apiRequest(admin, http.MethodPost, "/v1/admin/devices", header, body)
		if response.Code != want {
			t.Fatalf("register status = %d, want %d, body = %s", response.Code, want, response.Body.String())
		}
		if strings.Contains(response.Body.String(), token) || strings.Contains(response.Body.String(), "credential_hash") {
			t.Fatal("response registrasi membocorkan credential")
		}
	}
	for _, changed := range []string{
		registrationBody(testAuthDeviceID, "Nama lain", token),
		registrationBody(testAuthDeviceID, "Fedora", authFixtureToken(2)),
		registrationBody(otherDeviceID, "Fedora", token),
	} {
		if response := apiRequest(admin, http.MethodPost, "/v1/admin/devices", header, changed); response.Code != http.StatusConflict {
			t.Fatalf("registrasi berubah tidak ditolak: %d", response.Code)
		}
	}
	for range 2 {
		response := apiRequest(admin, http.MethodPost, "/v1/admin/devices/"+testAuthDeviceID+"/revoke", header, "")
		if response.Code != http.StatusOK {
			t.Fatalf("revoke status = %d", response.Code)
		}
	}
	if response := apiRequest(admin, http.MethodPost, "/v1/admin/devices", header, body); response.Code != http.StatusConflict {
		t.Fatalf("retry mengaktifkan credential revoked: %d", response.Code)
	}
	response := apiRequest(admin, http.MethodGet, "/v1/admin/devices", header, "")
	if response.Code != http.StatusOK || !strings.Contains(response.Body.String(), "revoked_at") || strings.Contains(response.Body.String(), token) {
		t.Fatalf("device list status = %d", response.Code)
	}
}

func TestAuthorizationErrorsDoNotAccessSyncStorage(t *testing.T) {
	called := false
	database := fakeDatabase{onPush: func(string, []storage.PushOperation) { called = true }, onPull: func(int64, int) { called = true }}
	request := httptest.NewRequest(http.MethodGet, "/v1/sync/pull?after=0", nil)
	request.Header.Add("Authorization", "Bearer "+testAuthToken)
	request.Header.Add("Authorization", "Bearer "+testAuthToken)
	response := httptest.NewRecorder()
	New(database).ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized || called {
		t.Fatalf("duplicate auth headers status = %d, storage called = %v", response.Code, called)
	}
}

func TestAdminValidatesRequestsAndHandlesMissingDevices(t *testing.T) {
	store := authenticatedTestStore(t)
	admin, err := NewAdmin(store, testAuthToken)
	if err != nil {
		t.Fatal(err)
	}
	header := "Bearer " + testAuthToken
	for _, test := range []struct {
		body   string
		status int
	}{
		{`{"protocol_version":2}`, http.StatusConflict},
		{`{"protocol_version":1,"unexpected":true}`, http.StatusBadRequest},
		{`{} {}`, http.StatusBadRequest},
		{registrationBody("invalid", "Fedora", authFixtureToken(1)), http.StatusBadRequest},
		{registrationBody(testAuthDeviceID, "", authFixtureToken(1)), http.StatusBadRequest},
		{registrationBody(testAuthDeviceID, "Fedora", "bad-token"), http.StatusBadRequest},
		{registrationBody(testAuthDeviceID, "Fedora", testAuthToken), http.StatusBadRequest},
		{strings.Repeat("x", 5000), http.StatusBadRequest},
	} {
		response := apiRequest(admin, http.MethodPost, "/v1/admin/devices", header, test.body)
		if response.Code != test.status {
			t.Fatalf("invalid request status = %d, want %d", response.Code, test.status)
		}
	}
	response := apiRequest(admin, http.MethodPost, "/v1/admin/devices/"+testAuthDeviceID+"/revoke", header, "")
	if response.Code != http.StatusNotFound {
		t.Fatalf("unknown device revoke status = %d", response.Code)
	}
}

func TestAuthenticationDatabaseFailureFailsClosed(t *testing.T) {
	called := false
	database := fakeDatabase{err: context.Canceled, onPull: func(int64, int) { called = true }}
	response := apiRequest(New(database), http.MethodGet, "/v1/sync/pull?after=0", "Bearer "+testAuthToken, "")
	if response.Code != http.StatusServiceUnavailable || called {
		t.Fatalf("database failure status = %d, storage called = %v", response.Code, called)
	}
}

func authenticatedTestStore(t *testing.T) *storage.Store {
	t.Helper()
	store, err := storage.Open(context.Background(), filepath.Join(t.TempDir(), "hub.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { store.Close() })
	return store
}

func authFixtureToken(value byte) string {
	return base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{value}, 32))
}

func registrationBody(deviceID, name, credential string) string {
	body, _ := json.Marshal(map[string]any{"protocol_version": 1, "device_id": deviceID, "name": name, "credential": credential})
	return string(body)
}

func apiRequest(handler http.Handler, method, target, credential, body string) *httptest.ResponseRecorder {
	request := httptest.NewRequest(method, target, strings.NewReader(body))
	if credential != "" {
		request.Header.Set("Authorization", credential)
	}
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}
