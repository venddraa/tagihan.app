package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

type fakeDatabase struct {
	err             error
	schemaVersion   int
	pushResults     []storage.PushResult
	pushErr         error
	onPush          func(string, []storage.PushOperation)
	bootstrapResult storage.BootstrapResult
	bootstrapErr    error
	pullPage        storage.PullPage
	pullErr         error
	onPull          func(int64, int)
}

func (database fakeDatabase) Pull(
	_ context.Context,
	after int64,
	limit int,
) (storage.PullPage, error) {
	if database.onPull != nil {
		database.onPull(after, limit)
	}
	return database.pullPage, database.pullErr
}

func (database fakeDatabase) Bootstrap(
	_ context.Context,
	_ storage.BootstrapInput,
) (storage.BootstrapResult, error) {
	return database.bootstrapResult, database.bootstrapErr
}

func (database fakeDatabase) Push(
	_ context.Context,
	deviceID string,
	operations []storage.PushOperation,
) ([]storage.PushResult, error) {
	if database.onPush != nil {
		database.onPush(deviceID, operations)
	}
	return database.pushResults, database.pushErr
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

func TestPushPassesValidatedBatchToStorage(t *testing.T) {
	t.Parallel()

	const operationID = "0199e7d0-0000-7000-8000-000000000002"
	requestBody := []byte(`{
		"protocol_version": 1,
		"device_id": "0199e7d0-0000-7000-8000-000000000001",
		"operations": [{
			"operation_id": "` + operationID + `",
			"entity_type": "bill",
			"entity_id": "0199e7d0-0000-7000-8000-000000000003",
			"operation_type": "bill.create",
			"base_version": 0,
			"payload": {"id":"0199e7d0-0000-7000-8000-000000000003"},
			"created_at": "2026-10-17T00:00:00Z"
		}]
	}`)
	called := false
	database := fakeDatabase{
		pushResults: []storage.PushResult{{
			OperationID:     operationID,
			Status:          "accepted",
			ServerSequences: []int64{1},
		}},
		onPush: func(deviceID string, operations []storage.PushOperation) {
			called = true
			if deviceID != "0199e7d0-0000-7000-8000-000000000001" {
				t.Errorf("deviceID = %q", deviceID)
			}
			if len(operations) != 1 || operations[0].OperationID != operationID {
				t.Errorf("operations = %#v", operations)
			}
		},
	}
	request := httptest.NewRequest(
		http.MethodPost,
		"/v1/sync/push",
		bytes.NewReader(requestBody),
	)
	request.Header.Set("Content-Type", "application/json; charset=utf-8")
	response := httptest.NewRecorder()

	New(database).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if !called {
		t.Fatal("storage Push tidak dipanggil")
	}
	var body struct {
		ProtocolVersion int                  `json:"protocol_version"`
		Results         []storage.PushResult `json:"results"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.ProtocolVersion != ProtocolVersion ||
		len(body.Results) != 1 ||
		body.Results[0].Status != "accepted" {
		t.Errorf("response body = %#v", body)
	}
}

func TestPushRejectsInvalidEnvelope(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name        string
		contentType string
		body        string
		wantStatus  int
	}{
		{
			name:        "content type",
			contentType: "text/plain",
			body:        `{}`,
			wantStatus:  http.StatusUnsupportedMediaType,
		},
		{
			name:        "protocol version",
			contentType: "application/json",
			body: `{
				"protocol_version": 2,
				"device_id": "0199e7d0-0000-7000-8000-000000000001",
				"operations": [{}]
			}`,
			wantStatus: http.StatusConflict,
		},
		{
			name:        "batch kosong",
			contentType: "application/json",
			body: `{
				"protocol_version": 1,
				"device_id": "0199e7d0-0000-7000-8000-000000000001",
				"operations": []
			}`,
			wantStatus: http.StatusBadRequest,
		},
		{
			name:        "field asing",
			contentType: "application/json",
			body: `{
				"protocol_version": 1,
				"device_id": "0199e7d0-0000-7000-8000-000000000001",
				"operations": [],
				"unexpected": true
			}`,
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()
			request := httptest.NewRequest(
				http.MethodPost,
				"/v1/sync/push",
				bytes.NewBufferString(test.body),
			)
			request.Header.Set("Content-Type", test.contentType)
			response := httptest.NewRecorder()
			New(fakeDatabase{}).ServeHTTP(response, request)

			if response.Code != test.wantStatus {
				t.Errorf(
					"status = %d, want %d, body = %s",
					response.Code,
					test.wantStatus,
					response.Body.String(),
				)
			}
		})
	}
}

func TestBootstrapReturnsDurableResult(t *testing.T) {
	t.Parallel()

	const bootstrapID = "0199e7d0-0000-7000-8000-000000000030"
	request := httptest.NewRequest(
		http.MethodPost,
		"/v1/sync/bootstrap",
		bytes.NewBufferString(`{
			"protocol_version": 1,
			"bootstrap_id": "`+bootstrapID+`",
			"device_id": "0199e7d0-0000-7000-8000-000000000001",
			"bills": [],
			"payments": [],
			"created_at": "2026-10-17T00:00:00Z"
		}`),
	)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	database := fakeDatabase{bootstrapResult: storage.BootstrapResult{
		BootstrapID:     bootstrapID,
		Status:          "accepted",
		ServerSequences: []int64{},
	}}

	New(database).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	var body map[string]any
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body["bootstrap_id"] != bootstrapID || body["status"] != "accepted" {
		t.Errorf("response body = %#v", body)
	}
}

func TestBootstrapRejectsNonEmptyHub(t *testing.T) {
	t.Parallel()

	request := httptest.NewRequest(
		http.MethodPost,
		"/v1/sync/bootstrap",
		bytes.NewBufferString(`{
			"protocol_version": 1,
			"bootstrap_id": "0199e7d0-0000-7000-8000-000000000030",
			"device_id": "0199e7d0-0000-7000-8000-000000000001",
			"bills": [],
			"payments": [],
			"created_at": "2026-10-17T00:00:00Z"
		}`),
	)
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()

	New(fakeDatabase{bootstrapErr: storage.ErrHubNotEmpty}).ServeHTTP(
		response,
		request,
	)

	if response.Code != http.StatusConflict {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
}

func TestPullReturnsPage(t *testing.T) {
	t.Parallel()

	called := false
	database := fakeDatabase{
		pullPage: storage.PullPage{
			Changes: []storage.PullChange{{
				ServerSequence: 8,
				OperationID:    "0199e7d0-0000-7000-8000-000000000002",
				EntityType:     "bill",
				EntityID:       "0199e7d0-0000-7000-8000-000000000003",
				Version:        2,
				Payload:        json.RawMessage(`{"id":"0199e7d0-0000-7000-8000-000000000003"}`),
				CreatedAt:      "2026-10-17T00:00:00Z",
			}},
			NextCursor: 8,
			HasMore:    true,
		},
		onPull: func(after int64, limit int) {
			called = true
			if after != 7 || limit != 1 {
				t.Errorf("Pull(%d, %d), want Pull(7, 1)", after, limit)
			}
		},
	}
	request := httptest.NewRequest(
		http.MethodGet,
		"/v1/sync/pull?after=7&limit=1",
		nil,
	)
	response := httptest.NewRecorder()

	New(database).ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if !called {
		t.Fatal("storage Pull tidak dipanggil")
	}
	var body struct {
		ProtocolVersion int                  `json:"protocol_version"`
		Changes         []storage.PullChange `json:"changes"`
		NextCursor      int64                `json:"next_cursor"`
		HasMore         bool                 `json:"has_more"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.ProtocolVersion != ProtocolVersion ||
		len(body.Changes) != 1 ||
		body.NextCursor != 8 ||
		!body.HasMore {
		t.Errorf("response body = %#v", body)
	}
}

func TestPullUsesDefaultLimit(t *testing.T) {
	t.Parallel()

	called := false
	request := httptest.NewRequest(http.MethodGet, "/v1/sync/pull?after=0", nil)
	response := httptest.NewRecorder()
	New(fakeDatabase{
		pullPage: storage.PullPage{Changes: []storage.PullChange{}},
		onPull: func(after int64, limit int) {
			called = true
			if after != 0 || limit != storage.MaxPullChanges {
				t.Errorf("Pull(%d, %d)", after, limit)
			}
		},
	}).ServeHTTP(response, request)

	if response.Code != http.StatusOK || !called {
		t.Fatalf("status = %d, called = %v", response.Code, called)
	}
	if body := response.Body.String(); !strings.Contains(body, `"changes":[]`) {
		t.Errorf("body = %s, want empty JSON array", body)
	}
}

func TestPullRejectsInvalidQuery(t *testing.T) {
	t.Parallel()

	tests := []string{
		"/v1/sync/pull",
		"/v1/sync/pull?after=-1",
		"/v1/sync/pull?after=nope",
		"/v1/sync/pull?after=0&limit=0",
		"/v1/sync/pull?after=0&limit=101",
		"/v1/sync/pull?after=0&unknown=1",
		"/v1/sync/pull?after=0&after=1",
	}
	for _, target := range tests {
		target := target
		t.Run(target, func(t *testing.T) {
			t.Parallel()
			request := httptest.NewRequest(http.MethodGet, target, nil)
			response := httptest.NewRecorder()

			New(fakeDatabase{}).ServeHTTP(response, request)

			if response.Code != http.StatusBadRequest {
				t.Errorf(
					"status = %d, want %d, body = %s",
					response.Code,
					http.StatusBadRequest,
					response.Body.String(),
				)
			}
		})
	}
}
