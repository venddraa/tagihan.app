package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/auth"
	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

type syncDatabase interface {
	databaseHealth
	AuthenticateDevice(context.Context, string) (storage.Device, error)
}

type authenticatedDeviceKey struct{}

func requireDevice(database syncDatabase, next http.HandlerFunc) http.HandlerFunc {
	return func(writer http.ResponseWriter, request *http.Request) {
		token := bearerToken(request)
		if token == "" {
			unauthorized(writer)
			return
		}
		ctx, cancel := context.WithTimeout(request.Context(), 5*time.Second)
		defer cancel()
		device, err := database.AuthenticateDevice(ctx, token)
		if errors.Is(err, storage.ErrDeviceUnauthenticated) {
			unauthorized(writer)
			return
		}
		if err != nil {
			writeAPIError(writer, http.StatusServiceUnavailable, "database_unavailable", "Credential belum dapat diperiksa.")
			return
		}
		// Batas waktu autentikasi tidak membatasi keseluruhan push/pull.
		request = request.WithContext(context.WithValue(request.Context(), authenticatedDeviceKey{}, device.ID))
		next(writer, request)
	}
}

func requireAdmin(token string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if !auth.EqualTokens(token, bearerToken(request)) {
			unauthorized(writer)
			return
		}
		next.ServeHTTP(writer, request)
	})
}

func bearerToken(request *http.Request) string {
	values := request.Header.Values("Authorization")
	if len(values) != 1 {
		return ""
	}
	parts := strings.Split(values[0], " ")
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || !auth.ValidToken(parts[1]) {
		return ""
	}
	return parts[1]
}

func unauthorized(writer http.ResponseWriter) {
	writer.Header().Set("WWW-Authenticate", `Bearer realm="tagihan-sync"`)
	writeAPIError(writer, http.StatusUnauthorized, "unauthorized", "Credential tidak valid atau akses telah dicabut.")
}
