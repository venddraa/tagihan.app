package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

const ProtocolVersion = 1

type databaseHealth interface {
	Ping(context.Context) error
	SchemaVersion(context.Context) (int, error)
	Push(context.Context, string, []storage.PushOperation) ([]storage.PushResult, error)
	Bootstrap(context.Context, storage.BootstrapInput) (storage.BootstrapResult, error)
	Pull(context.Context, int64, int) (storage.PullPage, error)
}

type handler struct {
	database databaseHealth
}

func New(database syncDatabase) http.Handler {
	handler := &handler{database: database}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/health", handler.health)
	mux.HandleFunc("POST /v1/sync/push", requireDevice(database, handler.push))
	mux.HandleFunc("GET /v1/sync/pull", requireDevice(database, handler.pull))
	return mux
}

func (h *handler) pull(writer http.ResponseWriter, request *http.Request) {
	query := request.URL.Query()
	queryIsValid := len(query["after"]) == 1 && len(query["limit"]) <= 1
	for name := range query {
		if name != "after" && name != "limit" {
			queryIsValid = false
		}
	}
	if !queryIsValid {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_query",
			"Query pull tidak valid.",
		)
		return
	}

	after, err := strconv.ParseInt(query.Get("after"), 10, 64)
	if err != nil || after < 0 {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_cursor",
			"Cursor pull harus berupa integer non-negatif.",
		)
		return
	}
	limit := storage.MaxPullChanges
	if query.Has("limit") {
		limit, err = strconv.Atoi(query.Get("limit"))
		if err != nil || limit < 1 || limit > storage.MaxPullChanges {
			writeAPIError(
				writer,
				http.StatusBadRequest,
				"invalid_limit",
				"Limit pull harus berada antara 1 dan 100.",
			)
			return
		}
	}

	ctx, cancel := context.WithTimeout(request.Context(), 15*time.Second)
	defer cancel()
	page, err := h.database.Pull(ctx, after, limit)
	if errors.Is(err, storage.ErrInvalidCursor) ||
		errors.Is(err, storage.ErrInvalidPullLimit) {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_query",
			"Query pull tidak valid.",
		)
		return
	}
	if err != nil {
		writeAPIError(
			writer,
			http.StatusServiceUnavailable,
			"database_unavailable",
			"Pull belum dapat diproses.",
		)
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"protocol_version": ProtocolVersion,
		"changes":          page.Changes,
		"next_cursor":      page.NextCursor,
		"has_more":         page.HasMore,
	})
}

type bootstrapRequest struct {
	ProtocolVersion int               `json:"protocol_version"`
	BootstrapID     string            `json:"bootstrap_id"`
	DeviceID        string            `json:"device_id"`
	Bills           []json.RawMessage `json:"bills"`
	Payments        []json.RawMessage `json:"payments"`
	CreatedAt       string            `json:"created_at"`
}

func (h *handler) bootstrap(writer http.ResponseWriter, request *http.Request) {
	if mediaType := strings.TrimSpace(strings.Split(
		request.Header.Get("Content-Type"),
		";",
	)[0]); mediaType != "application/json" {
		writeAPIError(
			writer,
			http.StatusUnsupportedMediaType,
			"unsupported_media_type",
			"Content-Type harus application/json.",
		)
		return
	}

	request.Body = http.MaxBytesReader(writer, request.Body, 8<<20)
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	var input bootstrapRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_json",
			"Request JSON tidak valid.",
		)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_json",
			"Request JSON tidak valid.",
		)
		return
	}
	if input.ProtocolVersion != ProtocolVersion {
		writeAPIError(
			writer,
			http.StatusConflict,
			"protocol_version_mismatch",
			"Protocol version tidak didukung.",
		)
		return
	}

	ctx, cancel := context.WithTimeout(request.Context(), 30*time.Second)
	defer cancel()
	result, err := h.database.Bootstrap(ctx, storage.BootstrapInput{
		BootstrapID: input.BootstrapID,
		DeviceID:    input.DeviceID,
		Bills:       input.Bills,
		Payments:    input.Payments,
		CreatedAt:   input.CreatedAt,
	})
	if errors.Is(err, storage.ErrInvalidBootstrap) {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_bootstrap",
			"Snapshot bootstrap tidak valid.",
		)
		return
	}
	if errors.Is(err, storage.ErrHubNotEmpty) {
		writeAPIError(
			writer,
			http.StatusConflict,
			"hub_not_empty",
			"Sync hub sudah pernah menerima data.",
		)
		return
	}
	if err != nil {
		writeAPIError(
			writer,
			http.StatusServiceUnavailable,
			"database_unavailable",
			"Bootstrap belum dapat diproses.",
		)
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"protocol_version": ProtocolVersion,
		"bootstrap_id":     result.BootstrapID,
		"status":           result.Status,
		"server_sequences": result.ServerSequences,
	})
}

func (h *handler) health(writer http.ResponseWriter, request *http.Request) {
	ctx, cancel := context.WithTimeout(request.Context(), 2*time.Second)
	defer cancel()

	if err := h.database.Ping(ctx); err != nil {
		writeJSON(writer, http.StatusServiceUnavailable, map[string]any{
			"status": "unavailable",
			"error":  "database unavailable",
		})
		return
	}

	schemaVersion, err := h.database.SchemaVersion(ctx)
	if err != nil {
		writeJSON(writer, http.StatusServiceUnavailable, map[string]any{
			"status": "unavailable",
			"error":  "database unavailable",
		})
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"status":                  "ok",
		"service":                 "tagihan-vendra-sync",
		"protocol_version":        ProtocolVersion,
		"database_schema_version": schemaVersion,
	})
}

type pushRequest struct {
	ProtocolVersion int                     `json:"protocol_version"`
	DeviceID        string                  `json:"device_id"`
	Operations      []storage.PushOperation `json:"operations"`
}

func (h *handler) push(writer http.ResponseWriter, request *http.Request) {
	if mediaType := strings.TrimSpace(strings.Split(
		request.Header.Get("Content-Type"),
		";",
	)[0]); mediaType != "application/json" {
		writeAPIError(
			writer,
			http.StatusUnsupportedMediaType,
			"unsupported_media_type",
			"Content-Type harus application/json.",
		)
		return
	}

	request.Body = http.MaxBytesReader(writer, request.Body, 1<<20)
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	var input pushRequest
	if err := decoder.Decode(&input); err != nil {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_json",
			"Request JSON tidak valid.",
		)
		return
	}
	if err := ensureJSONEnd(decoder); err != nil {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_json",
			"Request JSON tidak valid.",
		)
		return
	}
	if input.ProtocolVersion != ProtocolVersion {
		writeAPIError(
			writer,
			http.StatusConflict,
			"protocol_version_mismatch",
			"Protocol version tidak didukung.",
		)
		return
	}
	deviceID, _ := request.Context().Value(authenticatedDeviceKey{}).(string)
	if !strings.EqualFold(input.DeviceID, deviceID) {
		writeAPIError(writer, http.StatusForbidden, "device_identity_mismatch", "device_id tidak sesuai credential.")
		return
	}
	input.DeviceID = deviceID
	if len(input.Operations) == 0 {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"empty_batch",
			"Batch push tidak boleh kosong.",
		)
		return
	}

	ctx, cancel := context.WithTimeout(request.Context(), 15*time.Second)
	defer cancel()
	results, err := h.database.Push(ctx, input.DeviceID, input.Operations)
	if errors.Is(err, storage.ErrInvalidDevice) {
		writeAPIError(
			writer,
			http.StatusBadRequest,
			"invalid_device_id",
			"device_id tidak valid.",
		)
		return
	}
	if errors.Is(err, storage.ErrBatchTooLarge) {
		writeAPIError(
			writer,
			http.StatusRequestEntityTooLarge,
			"batch_too_large",
			"Batch push maksimal 100 operation.",
		)
		return
	}
	if err != nil {
		writeAPIError(
			writer,
			http.StatusServiceUnavailable,
			"database_unavailable",
			"Push belum dapat diproses.",
		)
		return
	}

	writeJSON(writer, http.StatusOK, map[string]any{
		"protocol_version": ProtocolVersion,
		"results":          results,
	})
}

func ensureJSONEnd(decoder *json.Decoder) error {
	var extra any
	err := decoder.Decode(&extra)
	if errors.Is(err, io.EOF) {
		return nil
	}
	if err == nil {
		return errors.New("multiple JSON values")
	}
	return err
}

func writeAPIError(
	writer http.ResponseWriter,
	status int,
	code string,
	message string,
) {
	writeJSON(writer, status, map[string]any{
		"error": map[string]string{
			"code":    code,
			"message": message,
		},
	})
}

func writeJSON(writer http.ResponseWriter, status int, value any) {
	writer.Header().Set("Cache-Control", "no-store")
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.Header().Set("Cache-Control", "no-store")
	writer.Header().Set("X-Content-Type-Options", "nosniff")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(value)
}
