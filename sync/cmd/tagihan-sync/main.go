package main

import (
	"context"
	"crypto/tls"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/auth"
	"github.com/venddraa/tagihan.app/sync/internal/httpapi"
	"github.com/venddraa/tagihan.app/sync/internal/pairing"
	"github.com/venddraa/tagihan.app/sync/internal/storage"
)

func main() {
	if err := run(); err != nil {
		slog.Error("sync service stopped", "error", err)
		os.Exit(1)
	}
}

func run() error {
	defaultDatabase, err := defaultDatabasePath()
	if err != nil {
		return err
	}

	listenAddress := flag.String(
		"listen",
		"127.0.0.1:8787",
		"alamat HTTP; milestone ini hanya mengizinkan loopback",
	)
	adminAddress := flag.String("admin-listen", "127.0.0.1:8788", "alamat kontrol admin; hanya loopback")
	adminTokenPath := flag.String("admin-token-file", filepath.Join(filepath.Dir(defaultDatabase), "admin.token"), "file credential kontrol admin lokal")
	pairingAddress := flag.String("pairing-listen", "", "aktifkan HTTPS pairing pada IP private/loopback tertentu, contoh 192.168.1.10:8789")
	identityPath := flag.String("pairing-identity-file", "", "identity dan private key HTTPS lokal; default <database>.tls-identity.json")
	databasePath := flag.String(
		"database",
		defaultDatabase,
		"path database SQLite milik sync hub",
	)
	flag.Parse()
	if *identityPath == "" {
		*identityPath = *databasePath + ".tls-identity.json"
	}

	if err := requireLoopback(*listenAddress); err != nil {
		return err
	}
	if err := requireLoopback(*adminAddress); err != nil {
		return err
	}
	if *pairingAddress != "" {
		if err := requirePairingAddress(*pairingAddress); err != nil {
			return err
		}
	}
	listener, err := net.Listen("tcp", *listenAddress)
	if err != nil {
		return fmt.Errorf("listen HTTP: %w", err)
	}
	defer listener.Close()
	adminListener, err := net.Listen("tcp", *adminAddress)
	if err != nil {
		return fmt.Errorf("listen admin HTTP: %w", err)
	}
	defer adminListener.Close()
	adminToken, err := auth.LoadOrCreateLocalToken(*adminTokenPath)
	if err != nil {
		return fmt.Errorf("prepare admin credential: %w", err)
	}

	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	store, err := storage.Open(ctx, *databasePath)
	if err != nil {
		return fmt.Errorf("open hub storage: %w", err)
	}
	defer store.Close()
	var manager *pairing.Manager
	var secureListener net.Listener
	if *pairingAddress != "" {
		identity, err := pairing.LoadIdentity(*identityPath)
		if err != nil {
			return fmt.Errorf("prepare TLS identity: %w", err)
		}
		configuration, err := identity.TLSConfig()
		if err != nil {
			return err
		}
		listener, err := net.Listen("tcp", *pairingAddress)
		if err != nil {
			return fmt.Errorf("listen pairing HTTPS: %w", err)
		}
		secureListener = tls.NewListener(listener, configuration)
		defer secureListener.Close()
		manager = pairing.New(store, pairing.Info{Enabled: true, HubID: identity.HubID, Endpoint: "https://" + listener.Addr().String(), Fingerprint: identity.Fingerprint(), CertificatePEM: identity.CertificatePEM})
	}
	adminHandler, err := httpapi.NewAdminWithPairing(store, adminToken, manager)
	if err != nil {
		return err
	}

	server := &http.Server{
		Addr:              *listenAddress,
		Handler:           httpapi.New(store),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	adminServer := &http.Server{
		Addr: *adminAddress, Handler: adminHandler,
		ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second,
		WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second,
	}

	servers := []*http.Server{server, adminServer}
	listeners := []net.Listener{listener, adminListener}
	if secureListener != nil {
		servers = append(servers, &http.Server{Handler: httpapi.NewPairingHandler(store, manager), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 15 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second})
		listeners = append(listeners, secureListener)
	}
	serverErrors := make(chan error, len(servers))
	for index, server := range servers {
		listener := listeners[index]
		defer server.Close()
		go func() {
			slog.Info("service listener started", "address", listener.Addr().String(), "tls", index == 2)
			serverErrors <- server.Serve(listener)
		}()
	}

	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(
			context.Background(),
			5*time.Second,
		)
		defer cancel()
		for _, server := range servers {
			if err := server.Shutdown(shutdownContext); err != nil {
				return fmt.Errorf("shutdown HTTP server: %w", err)
			}
		}
		for range len(servers) {
			if err := <-serverErrors; !errors.Is(err, http.ErrServerClosed) {
				return fmt.Errorf("serve HTTP: %w", err)
			}
		}
		slog.Info("sync service stopped")
		return nil
	case err := <-serverErrors:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return fmt.Errorf("serve HTTP: %w", err)
	}
}

func requirePairingAddress(address string) error {
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return errors.New("alamat pairing harus IP:port")
	}
	ip := net.ParseIP(host)
	number, err := strconv.Atoi(port)
	if err != nil || number < 1 || number > 65535 || ip == nil || ip.IsUnspecified() || (!ip.IsPrivate() && !ip.IsLoopback()) {
		return errors.New("pairing HTTPS harus memakai IP private/loopback spesifik dan port valid; wildcard atau IP publik tidak diizinkan")
	}
	return nil
}

func defaultDatabasePath() (string, error) {
	dataDirectory := os.Getenv("XDG_DATA_HOME")
	if dataDirectory == "" {
		homeDirectory, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("resolve home directory: %w", err)
		}
		dataDirectory = filepath.Join(homeDirectory, ".local", "share")
	}
	return filepath.Join(
		dataDirectory,
		"tagihan-vendra",
		"sync",
		"hub.sqlite",
	), nil
}

func requireLoopback(address string) error {
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return fmt.Errorf("alamat listen tidak valid: %w", err)
	}
	if host == "localhost" {
		return nil
	}

	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf(
			"alamat listen %q bukan loopback; pairing belum tersedia",
			address,
		)
	}
	return nil
}
