package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"mime"
	"net"
	"net/http"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/pairing"
	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

// NewPairingHandler dipasang hanya pada listener TLS. Tidak memuat rute admin
// maupun bootstrap; push/pull tetap melalui middleware credential perangkat.
func NewPairingHandler(database syncDatabase, manager *pairing.Manager) http.Handler {
	mux := http.NewServeMux()
	mux.Handle("/", New(database))
	mux.HandleFunc("POST /v1/pairing/requests", func(writer http.ResponseWriter, request *http.Request) {
		if !allowPairing(manager, writer, request) {
			return
		}
		var input pairing.RequestInput
		if !decodePairingJSON(writer, request, &input) {
			return
		}
		result, err := manager.Submit(input, bearerToken(request))
		writePairingResult(writer, result, err)
	})
	mux.HandleFunc("GET /v1/pairing/requests/{request_id}", func(writer http.ResponseWriter, request *http.Request) {
		if !allowPairing(manager, writer, request) {
			return
		}
		result, err := manager.Status(request.PathValue("request_id"), bearerToken(request))
		writePairingResult(writer, result, err)
	})
	mux.HandleFunc("POST /v1/pairing/requests/{request_id}/cancel", func(writer http.ResponseWriter, request *http.Request) {
		if !allowPairing(manager, writer, request) {
			return
		}
		result, err := manager.CancelRequest(request.PathValue("request_id"), bearerToken(request))
		writePairingResult(writer, result, err)
	})
	mux.HandleFunc("GET /v1/pairing/identity", requireDevice(database, func(writer http.ResponseWriter, request *http.Request) {
		writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": ProtocolVersion, "hub_id": manager.Info().HubID, "device_id": request.Context().Value(authenticatedDeviceKey{})})
	}))
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.TLS == nil {
			writeAPIError(writer, http.StatusUpgradeRequired, "https_required", "Pairing hanya tersedia melalui HTTPS.")
			return
		}
		mux.ServeHTTP(writer, request)
	})
}

func registerPairingAdmin(mux *http.ServeMux, manager *pairing.Manager) {
	mux.HandleFunc("GET /v1/admin/pairing", func(writer http.ResponseWriter, request *http.Request) {
		if manager == nil {
			writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": 1, "info": map[string]bool{"enabled": false}, "requests": []pairing.Request{}})
			return
		}
		writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": 1, "info": manager.Info(), "requests": manager.Requests(), "active_invitation": manager.ActiveInvitation()})
	})
	mux.HandleFunc("POST /v1/admin/pairing/invitations", func(writer http.ResponseWriter, request *http.Request) {
		if manager == nil {
			writeAPIError(writer, http.StatusServiceUnavailable, "pairing_disabled", "Jalankan service dengan --pairing-listen pada alamat lokal yang dipilih.")
			return
		}
		invitation, err := manager.CreateInvitation()
		if err != nil {
			pairingError(writer, err)
			return
		}
		writeJSON(writer, http.StatusCreated, map[string]any{"protocol_version": 1, "invitation": invitation})
	})
	mux.HandleFunc("POST /v1/admin/pairing/invitations/{invitation_id}/cancel", func(writer http.ResponseWriter, request *http.Request) {
		if manager == nil {
			pairingError(writer, pairing.ErrExpired)
			return
		}
		if err := manager.Cancel(request.PathValue("invitation_id")); err != nil {
			pairingError(writer, err)
			return
		}
		writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": 1, "status": "cancelled"})
	})
	for _, decision := range []string{"approve", "reject"} {
		mux.HandleFunc("POST /v1/admin/pairing/requests/{request_id}/"+decision, func(writer http.ResponseWriter, request *http.Request) {
			if manager == nil {
				pairingError(writer, pairing.ErrExpired)
				return
			}
			ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
			defer cancel()
			result, err := manager.Decide(ctx, request.PathValue("request_id"), decision == "approve")
			writePairingResult(writer, result, err)
		})
	}
}

func allowPairing(manager *pairing.Manager, writer http.ResponseWriter, request *http.Request) bool {
	address, _, err := net.SplitHostPort(request.RemoteAddr)
	if err != nil {
		address = request.RemoteAddr
	}
	if !manager.Allow(address) {
		writer.Header().Set("Retry-After", "60")
		writeAPIError(writer, http.StatusTooManyRequests, "rate_limited", "Terlalu banyak request pairing. Coba lagi sebentar.")
		return false
	}
	return true
}

func decodePairingJSON(writer http.ResponseWriter, request *http.Request, target any) bool {
	contentType, _, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || contentType != "application/json" {
		writeAPIError(writer, http.StatusUnsupportedMediaType, "unsupported_media_type", "Content-Type harus application/json.")
		return false
	}
	request.Body = http.MaxBytesReader(writer, request.Body, 4096)
	decoder := json.NewDecoder(request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil || ensureJSONEnd(decoder) != nil {
		writeAPIError(writer, http.StatusBadRequest, "invalid_json", "Request pairing tidak valid.")
		return false
	}
	return true
}

func writePairingResult(writer http.ResponseWriter, result pairing.Request, err error) {
	if err != nil {
		pairingError(writer, err)
		return
	}
	writeJSON(writer, http.StatusOK, map[string]any{"protocol_version": 1, "request": result})
}

func pairingError(writer http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, pairing.ErrUnauthorized):
		unauthorized(writer)
	case errors.Is(err, pairing.ErrExpired):
		writeAPIError(writer, http.StatusGone, "pairing_expired", "Undangan atau request sudah berakhir. Buat undangan baru.")
	case errors.Is(err, pairing.ErrConflict), errors.Is(err, storage.ErrDeviceRegistrationConflict):
		writeAPIError(writer, http.StatusConflict, "pairing_conflict", "Undangan, identitas perangkat, atau request sudah dipakai.")
	case errors.Is(err, pairing.ErrInvalid):
		writeAPIError(writer, http.StatusBadRequest, "invalid_pairing", "Request pairing tidak valid.")
	default:
		writeAPIError(writer, http.StatusServiceUnavailable, "database_unavailable", "Pairing belum dapat diselesaikan.")
	}
}
