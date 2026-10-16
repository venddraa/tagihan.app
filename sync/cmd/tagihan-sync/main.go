package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/venddraa/tagihan.app/sync/internal/httpapi"
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
	databasePath := flag.String(
		"database",
		defaultDatabase,
		"path database SQLite milik sync hub",
	)
	flag.Parse()

	if err := requireLoopback(*listenAddress); err != nil {
		return err
	}
	listener, err := net.Listen("tcp", *listenAddress)
	if err != nil {
		return fmt.Errorf("listen HTTP: %w", err)
	}
	defer listener.Close()

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

	server := &http.Server{
		Addr:              *listenAddress,
		Handler:           httpapi.New(store),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		slog.Info("sync service started", "address", listener.Addr().String())
		serverErrors <- server.Serve(listener)
	}()

	select {
	case <-ctx.Done():
		shutdownContext, cancel := context.WithTimeout(
			context.Background(),
			5*time.Second,
		)
		defer cancel()
		if err := server.Shutdown(shutdownContext); err != nil {
			return fmt.Errorf("shutdown HTTP server: %w", err)
		}
		if err := <-serverErrors; !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("serve HTTP: %w", err)
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
