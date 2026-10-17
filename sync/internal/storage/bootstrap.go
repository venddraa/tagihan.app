package storage

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
)

const MaxBootstrapRecords = 10_000

var (
	ErrInvalidBootstrap = errors.New("snapshot bootstrap tidak valid")
	ErrHubNotEmpty      = errors.New("sync hub sudah berisi data")
)

type BootstrapInput struct {
	BootstrapID string            `json:"bootstrap_id"`
	DeviceID    string            `json:"device_id"`
	Bills       []json.RawMessage `json:"bills"`
	Payments    []json.RawMessage `json:"payments"`
	CreatedAt   string            `json:"created_at"`
}

type BootstrapResult struct {
	BootstrapID     string  `json:"bootstrap_id"`
	Status          string  `json:"status"`
	ServerSequences []int64 `json:"server_sequences"`
}

type decodedBootstrap struct {
	bills       []billSnapshot
	billJSON    []string
	payments    []paymentSnapshot
	paymentJSON []string
	createdAtMS int64
	payloadHash string
}

func (s *Store) Bootstrap(
	ctx context.Context,
	input BootstrapInput,
) (BootstrapResult, error) {
	decoded, err := validateBootstrap(input)
	if err != nil {
		return BootstrapResult{}, err
	}

	transaction, err := s.database.BeginTx(ctx, nil)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("begin bootstrap: %w", err)
	}
	defer transaction.Rollback()

	stored, found, err := findStoredBootstrap(
		ctx,
		transaction,
		input,
		decoded.payloadHash,
	)
	if err != nil {
		return BootstrapResult{}, err
	}
	if found {
		if stored.Status == "accepted" {
			stored.Status = "duplicate"
		}
		return stored, nil
	}

	empty, err := hubIsEmpty(ctx, transaction)
	if err != nil {
		return BootstrapResult{}, err
	}
	if !empty {
		return BootstrapResult{}, ErrHubNotEmpty
	}

	if _, err := transaction.ExecContext(
		ctx,
		`INSERT INTO operations(
			operation_id, device_id, payload_hash, result_status, result_json, created_at_ms
		) VALUES (?, ?, ?, 'accepted', '{}', ?)`,
		input.BootstrapID,
		input.DeviceID,
		decoded.payloadHash,
		decoded.createdAtMS,
	); err != nil {
		return BootstrapResult{}, fmt.Errorf("insert bootstrap operation: %w", err)
	}

	sequences := make(
		[]int64,
		0,
		len(decoded.bills)+len(decoded.payments),
	)
	for index, bill := range decoded.bills {
		deletedAtMS, _ := parseOptionalTimestamp(bill.DeletedAt)
		updatedAtMS, _ := parseTimestamp(bill.UpdatedAt)
		if _, err := transaction.ExecContext(
			ctx,
			`INSERT INTO entity_heads(
				entity_type, entity_id, version, payload_json, deleted_at_ms, updated_at_ms
			) VALUES ('bill', ?, ?, ?, ?, ?)`,
			bill.ID,
			bill.Version,
			decoded.billJSON[index],
			deletedAtMS,
			updatedAtMS,
		); err != nil {
			return BootstrapResult{}, fmt.Errorf("insert bootstrap bill: %w", err)
		}
		sequence, err := insertChange(
			ctx,
			transaction,
			input.BootstrapID,
			"bill",
			bill.ID,
			bill.Version,
			decoded.billJSON[index],
			decoded.createdAtMS,
		)
		if err != nil {
			return BootstrapResult{}, err
		}
		sequences = append(sequences, sequence)
	}
	for index, payment := range decoded.payments {
		deletedAtMS, _ := parseOptionalTimestamp(payment.DeletedAt)
		updatedAtMS, _ := parseTimestamp(payment.UpdatedAt)
		if _, err := transaction.ExecContext(
			ctx,
			`INSERT INTO entity_heads(
				entity_type, entity_id, version, payload_json, deleted_at_ms, updated_at_ms
			) VALUES ('payment', ?, ?, ?, ?, ?)`,
			payment.ID,
			payment.Version,
			decoded.paymentJSON[index],
			deletedAtMS,
			updatedAtMS,
		); err != nil {
			return BootstrapResult{}, fmt.Errorf("insert bootstrap payment: %w", err)
		}
		sequence, err := insertChange(
			ctx,
			transaction,
			input.BootstrapID,
			"payment",
			payment.ID,
			payment.Version,
			decoded.paymentJSON[index],
			decoded.createdAtMS,
		)
		if err != nil {
			return BootstrapResult{}, err
		}
		sequences = append(sequences, sequence)
	}

	result := BootstrapResult{
		BootstrapID:     input.BootstrapID,
		Status:          "accepted",
		ServerSequences: sequences,
	}
	resultJSON, err := json.Marshal(result)
	if err != nil {
		return BootstrapResult{}, fmt.Errorf("encode bootstrap result: %w", err)
	}
	if _, err := transaction.ExecContext(
		ctx,
		`UPDATE operations SET result_json = ? WHERE operation_id = ?`,
		string(resultJSON),
		input.BootstrapID,
	); err != nil {
		return BootstrapResult{}, fmt.Errorf("update bootstrap result: %w", err)
	}
	if err := transaction.Commit(); err != nil {
		return BootstrapResult{}, fmt.Errorf("commit bootstrap: %w", err)
	}
	return result, nil
}

func validateBootstrap(input BootstrapInput) (decodedBootstrap, error) {
	if !uuidV7Pattern.MatchString(input.BootstrapID) ||
		!uuidV7Pattern.MatchString(input.DeviceID) ||
		len(input.Bills)+len(input.Payments) > MaxBootstrapRecords {
		return decodedBootstrap{}, ErrInvalidBootstrap
	}
	createdAtMS, err := parseTimestamp(input.CreatedAt)
	if err != nil {
		return decodedBootstrap{}, ErrInvalidBootstrap
	}
	payloadHash, err := bootstrapHash(input)
	if err != nil {
		return decodedBootstrap{}, ErrInvalidBootstrap
	}

	decoded := decodedBootstrap{
		bills:       make([]billSnapshot, 0, len(input.Bills)),
		billJSON:    make([]string, 0, len(input.Bills)),
		payments:    make([]paymentSnapshot, 0, len(input.Payments)),
		paymentJSON: make([]string, 0, len(input.Payments)),
		createdAtMS: createdAtMS,
		payloadHash: payloadHash,
	}
	billIDs := make(map[string]bool, len(input.Bills))
	for _, rawBill := range input.Bills {
		var bill billSnapshot
		if decodeStrict(rawBill, &bill) != nil || validateBill(bill) != "" {
			return decodedBootstrap{}, ErrInvalidBootstrap
		}
		if billIDs[bill.ID] {
			return decodedBootstrap{}, ErrInvalidBootstrap
		}
		billIDs[bill.ID] = true
		canonical, _ := canonicalJSON(rawBill)
		decoded.bills = append(decoded.bills, bill)
		decoded.billJSON = append(decoded.billJSON, string(canonical))
	}

	paymentIDs := make(map[string]bool, len(input.Payments))
	for _, rawPayment := range input.Payments {
		var payment paymentSnapshot
		if decodeStrict(rawPayment, &payment) != nil ||
			validatePayment(payment) != "" ||
			!billIDs[payment.BillID] ||
			paymentIDs[payment.ID] {
			return decodedBootstrap{}, ErrInvalidBootstrap
		}
		paymentIDs[payment.ID] = true
		canonical, _ := canonicalJSON(rawPayment)
		decoded.payments = append(decoded.payments, payment)
		decoded.paymentJSON = append(decoded.paymentJSON, string(canonical))
	}

	return decoded, nil
}

func findStoredBootstrap(
	ctx context.Context,
	transaction *sql.Tx,
	input BootstrapInput,
	payloadHash string,
) (BootstrapResult, bool, error) {
	var storedDeviceID string
	var storedHash string
	var resultJSON string
	err := transaction.QueryRowContext(
		ctx,
		`SELECT device_id, payload_hash, result_json
		 FROM operations WHERE operation_id = ?`,
		input.BootstrapID,
	).Scan(&storedDeviceID, &storedHash, &resultJSON)
	if errors.Is(err, sql.ErrNoRows) {
		return BootstrapResult{}, false, nil
	}
	if err != nil {
		return BootstrapResult{}, false, fmt.Errorf("find bootstrap result: %w", err)
	}
	if storedDeviceID != input.DeviceID || storedHash != payloadHash {
		return BootstrapResult{}, false, ErrHubNotEmpty
	}
	var result BootstrapResult
	if err := json.Unmarshal([]byte(resultJSON), &result); err != nil {
		return BootstrapResult{}, false, fmt.Errorf("decode bootstrap result: %w", err)
	}
	return result, true, nil
}

func hubIsEmpty(ctx context.Context, transaction *sql.Tx) (bool, error) {
	for _, table := range []string{"operations", "entity_heads", "changes"} {
		var count int
		if err := transaction.QueryRowContext(
			ctx,
			"SELECT COUNT(*) FROM "+table,
		).Scan(&count); err != nil {
			return false, fmt.Errorf("count %s: %w", table, err)
		}
		if count != 0 {
			return false, nil
		}
	}
	return true, nil
}

func bootstrapHash(input BootstrapInput) (string, error) {
	var bills []any
	for _, raw := range input.Bills {
		var value any
		if err := json.Unmarshal(raw, &value); err != nil {
			return "", err
		}
		bills = append(bills, value)
	}
	var payments []any
	for _, raw := range input.Payments {
		var value any
		if err := json.Unmarshal(raw, &value); err != nil {
			return "", err
		}
		payments = append(payments, value)
	}
	canonical, err := json.Marshal(struct {
		Bills     []any  `json:"bills"`
		Payments  []any  `json:"payments"`
		CreatedAt string `json:"created_at"`
	}{Bills: bills, Payments: payments, CreatedAt: input.CreatedAt})
	if err != nil {
		return "", err
	}
	return hashBytes(canonical), nil
}
