package storage

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

const SchemaVersion = 2

type Store struct {
	database *sql.DB
}

func Open(ctx context.Context, path string) (*Store, error) {
	if path == "" {
		return nil, errors.New("database path tidak boleh kosong")
	}

	absolutePath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve database path: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(absolutePath), 0o700); err != nil {
		return nil, fmt.Errorf("create database directory: %w", err)
	}

	file, err := os.OpenFile(absolutePath, os.O_CREATE, 0o600)
	if err != nil {
		return nil, fmt.Errorf("create database file: %w", err)
	}
	if err := file.Close(); err != nil {
		return nil, fmt.Errorf("close database file: %w", err)
	}
	if err := os.Chmod(absolutePath, 0o600); err != nil {
		return nil, fmt.Errorf("secure database file: %w", err)
	}

	databaseURL := &url.URL{Scheme: "file", Path: absolutePath}
	query := databaseURL.Query()
	query.Set("_busy_timeout", "5000")
	query.Set("_foreign_keys", "on")
	databaseURL.RawQuery = query.Encode()

	database, err := sql.Open("sqlite3", databaseURL.String())
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	database.SetMaxOpenConns(1)
	database.SetMaxIdleConns(1)

	store := &Store{database: database}
	if err := store.prepare(ctx); err != nil {
		database.Close()
		return nil, err
	}

	return store, nil
}

func (s *Store) prepare(ctx context.Context) error {
	if err := s.database.PingContext(ctx); err != nil {
		return fmt.Errorf("ping database: %w", err)
	}

	var journalMode string
	if err := s.database.QueryRowContext(
		ctx,
		"PRAGMA journal_mode = WAL",
	).Scan(&journalMode); err != nil {
		return fmt.Errorf("enable WAL: %w", err)
	}
	if journalMode != "wal" {
		return fmt.Errorf("enable WAL: mode returned %q", journalMode)
	}

	if err := s.migrate(ctx); err != nil {
		return fmt.Errorf("migrate database: %w", err)
	}

	return nil
}

func (s *Store) migrate(ctx context.Context) error {
	transaction, err := s.database.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin migration: %w", err)
	}
	defer transaction.Rollback()

	var version int
	if err := transaction.QueryRowContext(ctx, "PRAGMA user_version").Scan(&version); err != nil {
		return fmt.Errorf("read schema version: %w", err)
	}
	if version < 0 || version > SchemaVersion {
		return fmt.Errorf(
			"database schema version %d tidak didukung (service mendukung %d)",
			version,
			SchemaVersion,
		)
	}

	for version < SchemaVersion {
		nextVersion := version + 1
		statements := schemaStatements
		if nextVersion == 2 {
			statements = deviceSchemaStatements
		}
		for _, statement := range statements {
			if _, err := transaction.ExecContext(ctx, statement); err != nil {
				return fmt.Errorf("apply schema version %d: %w", nextVersion, err)
			}
		}
		// nextVersion hanya berasal dari versi migration yang dikenal service.
		if _, err := transaction.ExecContext(ctx, fmt.Sprintf(
			"PRAGMA user_version = %d", nextVersion,
		)); err != nil {
			return fmt.Errorf("set schema version: %w", err)
		}
		version = nextVersion
	}

	if err := transaction.Commit(); err != nil {
		return fmt.Errorf("commit migration: %w", err)
	}
	return nil
}

func (s *Store) Ping(ctx context.Context) error {
	return s.database.PingContext(ctx)
}

func (s *Store) SchemaVersion(ctx context.Context) (int, error) {
	var version int
	if err := s.database.QueryRowContext(
		ctx,
		"PRAGMA user_version",
	).Scan(&version); err != nil {
		return 0, fmt.Errorf("read schema version: %w", err)
	}
	return version, nil
}

func (s *Store) Close() error {
	return s.database.Close()
}

var schemaStatements = []string{
	`CREATE TABLE operations (
		operation_id TEXT PRIMARY KEY,
		device_id TEXT NOT NULL,
		payload_hash TEXT NOT NULL,
		result_status TEXT NOT NULL CHECK (
			result_status IN ('accepted', 'duplicate', 'conflict', 'rejected')
		),
		result_json TEXT NOT NULL,
		created_at_ms INTEGER NOT NULL
	)`,
	`CREATE TABLE entity_heads (
		entity_type TEXT NOT NULL CHECK (entity_type IN ('bill', 'payment')),
		entity_id TEXT NOT NULL,
		version INTEGER NOT NULL CHECK (version >= 1),
		payload_json TEXT NOT NULL,
		deleted_at_ms INTEGER,
		updated_at_ms INTEGER NOT NULL,
		PRIMARY KEY (entity_type, entity_id)
	)`,
	`CREATE TABLE changes (
		server_sequence INTEGER PRIMARY KEY AUTOINCREMENT,
		operation_id TEXT NOT NULL,
		entity_type TEXT NOT NULL CHECK (entity_type IN ('bill', 'payment')),
		entity_id TEXT NOT NULL,
		version INTEGER NOT NULL CHECK (version >= 1),
		payload_json TEXT NOT NULL,
		created_at_ms INTEGER NOT NULL,
		FOREIGN KEY (operation_id) REFERENCES operations(operation_id),
		UNIQUE (operation_id, entity_type, entity_id)
	)`,
	`CREATE INDEX changes_entity ON changes(entity_type, entity_id)`,
	`CREATE TABLE hub_metadata (
		key TEXT PRIMARY KEY,
		value TEXT NOT NULL
	)`,
	`INSERT INTO hub_metadata(key, value) VALUES ('protocol_version', '1')`,
}

var deviceSchemaStatements = []string{
	`CREATE TABLE devices (
		device_id TEXT PRIMARY KEY NOT NULL,
		name TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
		credential_hash BLOB NOT NULL UNIQUE CHECK (
			typeof(credential_hash) = 'blob' AND length(credential_hash) = 32
		),
		created_at_ms INTEGER NOT NULL,
		revoked_at_ms INTEGER
	)`,
}
