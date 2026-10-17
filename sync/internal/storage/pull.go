package storage

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

const MaxPullChanges = 100

var (
	ErrInvalidCursor    = errors.New("cursor pull tidak valid")
	ErrInvalidPullLimit = errors.New("limit pull tidak valid")
)

type PullChange struct {
	ServerSequence int64           `json:"server_sequence"`
	OperationID    string          `json:"operation_id"`
	EntityType     string          `json:"entity_type"`
	EntityID       string          `json:"entity_id"`
	Version        int             `json:"version"`
	Payload        json.RawMessage `json:"payload"`
	CreatedAt      string          `json:"created_at"`
}

type PullPage struct {
	Changes    []PullChange `json:"changes"`
	NextCursor int64        `json:"next_cursor"`
	HasMore    bool         `json:"has_more"`
}

func (s *Store) Pull(
	ctx context.Context,
	after int64,
	limit int,
) (PullPage, error) {
	if after < 0 {
		return PullPage{}, ErrInvalidCursor
	}
	if limit < 1 || limit > MaxPullChanges {
		return PullPage{}, ErrInvalidPullLimit
	}

	rows, err := s.database.QueryContext(
		ctx,
		`SELECT
			server_sequence,
			operation_id,
			entity_type,
			entity_id,
			version,
			payload_json,
			created_at_ms
		 FROM changes
		 WHERE server_sequence > ?
		 ORDER BY server_sequence ASC
		 LIMIT ?`,
		after,
		limit+1,
	)
	if err != nil {
		return PullPage{}, fmt.Errorf("query pull changes: %w", err)
	}
	defer rows.Close()

	changes := make([]PullChange, 0, limit)
	hasMore := false
	for rows.Next() {
		var change PullChange
		var payloadJSON string
		var createdAtMS int64
		if err := rows.Scan(
			&change.ServerSequence,
			&change.OperationID,
			&change.EntityType,
			&change.EntityID,
			&change.Version,
			&payloadJSON,
			&createdAtMS,
		); err != nil {
			return PullPage{}, fmt.Errorf("scan pull change: %w", err)
		}
		if len(changes) == limit {
			hasMore = true
			break
		}
		change.Payload = json.RawMessage(payloadJSON)
		change.CreatedAt = time.UnixMilli(createdAtMS).UTC().Format(time.RFC3339Nano)
		changes = append(changes, change)
	}
	if err := rows.Err(); err != nil {
		return PullPage{}, fmt.Errorf("iterate pull changes: %w", err)
	}

	nextCursor := after
	if len(changes) > 0 {
		nextCursor = changes[len(changes)-1].ServerSequence
	}
	return PullPage{
		Changes:    changes,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}
