package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"mime"
	"net/http"
	"strings"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/auth"
	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

type adminDatabase interface {
	syncDatabase
	RegisterDevice(context.Context, string, string, string) (storage.Device, error)
	ListDevices(context.Context) ([]storage.Device, error)
	RevokeDevice(context.Context, string) (storage.Device, error)
}

// NewAdmin hanya boleh dipasang pada listener loopback kontrol lokal.
func NewAdmin(database adminDatabase, token string) (http.Handler, error) {
	if !auth.ValidToken(token) {
		return nil, errors.New("credential admin tidak valid")
	}
	handler := &handler{database: database}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/sync/bootstrap", handler.bootstrap)
	mux.HandleFunc("GET /v1/admin/devices", func(writer http.ResponseWriter, request *http.Request) {
		ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
		defer cancel()
		devices, err := database.ListDevices(ctx)
		if err != nil {
			writeAPIError(writer, http.StatusServiceUnavailable, "database_unavailable", "Daftar perangkat belum dapat dibaca.")
			return
		}
		writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": ProtocolVersion, "devices": devices})
	})
	mux.HandleFunc("POST /v1/admin/devices", func(writer http.ResponseWriter, request *http.Request) {
		mediaType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
		if err != nil || mediaType != "application/json" {
			writeAPIError(writer, http.StatusUnsupportedMediaType, "unsupported_media_type", "Content-Type harus application/json.")
			return
		}
		request.Body = http.MaxBytesReader(writer, request.Body, 4096)
		decoder := json.NewDecoder(request.Body)
		decoder.DisallowUnknownFields()
		var input struct {
			ProtocolVersion int    `json:"protocol_version"`
			DeviceID        string `json:"device_id"`
			Name            string `json:"name"`
			Credential      string `json:"credential"`
		}
		if err := decoder.Decode(&input); err != nil || ensureJSONEnd(decoder) != nil {
			writeAPIError(writer, http.StatusBadRequest, "invalid_json", "Request JSON tidak valid.")
			return
		}
		if input.ProtocolVersion != ProtocolVersion {
			writeAPIError(writer, http.StatusConflict, "protocol_version_mismatch", "Protocol version tidak didukung.")
			return
		}
		if auth.EqualTokens(token, input.Credential) {
			writeAPIError(writer, http.StatusBadRequest, "invalid_device", "Credential perangkat harus berbeda dari credential admin.")
			return
		}
		ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
		defer cancel()
		device, err := database.RegisterDevice(ctx, input.DeviceID, input.Name, input.Credential)
		status := http.StatusCreated
		if errors.Is(err, storage.ErrDeviceRegistrationConflict) {
			// Retry setelah response hilang aman hanya untuk token, ID, dan nama
			// yang sama. AuthenticateDevice selalu menolak credential revoked.
			device, err = database.AuthenticateDevice(ctx, input.Credential)
			if errors.Is(err, storage.ErrDeviceUnauthenticated) ||
				(err == nil && (device.ID != strings.ToLower(input.DeviceID) || device.Name != strings.TrimSpace(input.Name))) {
				writeAPIError(writer, http.StatusConflict, "device_registration_conflict", "Identitas atau credential perangkat sudah dipakai.")
				return
			}
			status = http.StatusOK
		}
		if errors.Is(err, storage.ErrInvalidDevice) || errors.Is(err, storage.ErrInvalidDeviceName) || errors.Is(err, storage.ErrInvalidDeviceCredential) {
			writeAPIError(writer, http.StatusBadRequest, "invalid_device", "Identitas, nama, atau credential perangkat tidak valid.")
			return
		}
		if err != nil {
			writeAPIError(writer, http.StatusServiceUnavailable, "database_unavailable", "Registrasi perangkat belum dapat disimpan.")
			return
		}
		writeJSON(writer, status, map[string]any{"protocol_version": ProtocolVersion, "device": device})
	})
	mux.HandleFunc("POST /v1/admin/devices/{device_id}/revoke", func(writer http.ResponseWriter, request *http.Request) {
		ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
		defer cancel()
		device, err := database.RevokeDevice(ctx, request.PathValue("device_id"))
		if errors.Is(err, storage.ErrInvalidDevice) {
			writeAPIError(writer, http.StatusBadRequest, "invalid_device_id", "device_id tidak valid.")
			return
		}
		if errors.Is(err, storage.ErrDeviceNotFound) {
			writeAPIError(writer, http.StatusNotFound, "device_not_found", "Perangkat tidak ditemukan.")
			return
		}
		if err != nil {
			writeAPIError(writer, http.StatusServiceUnavailable, "database_unavailable", "Pencabutan akses belum dapat disimpan.")
			return
		}
		writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": ProtocolVersion, "device": device})
	})
	return requireAdmin(token, mux), nil
}
