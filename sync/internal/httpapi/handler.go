package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"time"
)

const ProtocolVersion = 1

type databaseHealth interface {
	Ping(context.Context) error
	SchemaVersion(context.Context) (int, error)
}

type handler struct {
	database databaseHealth
}

func New(database databaseHealth) http.Handler {
	handler := &handler{database: database}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/health", handler.health)
	return mux
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

func writeJSON(writer http.ResponseWriter, status int, value any) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.Header().Set("Cache-Control", "no-store")
	writer.Header().Set("X-Content-Type-Options", "nosniff")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(value)
}
