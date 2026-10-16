package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

type fakeDatabase struct {
	err           error
	schemaVersion int
}

func (database fakeDatabase) Ping(context.Context) error {
	return database.err
}

func (database fakeDatabase) SchemaVersion(context.Context) (int, error) {
	if database.err != nil {
		return 0, database.err
	}
	return database.schemaVersion, nil
}

func TestHealth(t *testing.T) {
	t.Parallel()

	request := httptest.NewRequest(http.MethodGet, "/v1/health", nil)
	response := httptest.NewRecorder()
	New(fakeDatabase{schemaVersion: 1}).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", response.Code, http.StatusOK)
	}
	if contentType := response.Header().Get("Content-Type"); contentType != "application/json; charset=utf-8" {
		t.Errorf("Content-Type = %q", contentType)
	}

	var body map[string]any
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status body = %v, want ok", body["status"])
	}
	if body["service"] != "tagihan-vendra-sync" {
		t.Errorf("service = %v", body["service"])
	}
	if body["protocol_version"] != float64(ProtocolVersion) {
		t.Errorf("protocol_version = %v", body["protocol_version"])
	}
	if body["database_schema_version"] != float64(1) {
		t.Errorf("database_schema_version = %v", body["database_schema_version"])
	}
}

func TestHealthWhenDatabaseUnavailable(t *testing.T) {
	t.Parallel()

	request := httptest.NewRequest(http.MethodGet, "/v1/health", nil)
	response := httptest.NewRecorder()
	New(fakeDatabase{err: errors.New("database closed")}).ServeHTTP(
		response,
		request,
	)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf(
			"status = %d, want %d",
			response.Code,
			http.StatusServiceUnavailable,
		)
	}
}

func TestHealthRejectsPost(t *testing.T) {
	t.Parallel()

	request := httptest.NewRequest(http.MethodPost, "/v1/health", nil)
	response := httptest.NewRecorder()
	New(fakeDatabase{schemaVersion: 1}).ServeHTTP(response, request)

	if response.Code != http.StatusMethodNotAllowed {
		t.Fatalf(
			"status = %d, want %d",
			response.Code,
			http.StatusMethodNotAllowed,
		)
	}
}
