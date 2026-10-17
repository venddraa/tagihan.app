package storage

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strings"
	"time"
)

const MaxPushOperations = 100

var (
	ErrInvalidDevice = errors.New("device_id harus berupa UUIDv7")
	ErrBatchTooLarge = errors.New("batch push melebihi batas")
	uuidV7Pattern    = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
)

type PushOperation struct {
	OperationID   string          `json:"operation_id"`
	EntityType    string          `json:"entity_type"`
	EntityID      string          `json:"entity_id"`
	OperationType string          `json:"operation_type"`
	BaseVersion   int             `json:"base_version"`
	Payload       json.RawMessage `json:"payload"`
	CreatedAt     string          `json:"created_at"`
}

type PushResult struct {
	OperationID     string  `json:"operation_id"`
	Status          string  `json:"status"`
	ServerSequences []int64 `json:"server_sequences"`
	ErrorCode       string  `json:"error_code,omitempty"`
	EntityType      string  `json:"entity_type,omitempty"`
	EntityID        string  `json:"entity_id,omitempty"`
	CurrentVersion  *int    `json:"current_version,omitempty"`
}

type entityKey struct {
	typeName string
	id       string
}

type basicOperation struct {
	createdAtMS int64
	payloadHash string
}

type billSnapshot struct {
	ID               string  `json:"id"`
	Name             string  `json:"name"`
	Category         *string `json:"category"`
	AmountMinorUnits int64   `json:"amount_minor_units"`
	Currency         string  `json:"currency"`
	BillingCycle     string  `json:"billing_cycle"`
	NextDueDate      string  `json:"next_due_date"`
	StartDate        string  `json:"start_date"`
	Status           string  `json:"status"`
	Notes            *string `json:"notes"`
	CreatedAt        string  `json:"created_at"`
	UpdatedAt        string  `json:"updated_at"`
	DeletedAt        *string `json:"deleted_at"`
	Version          int     `json:"version"`
}

type paymentSnapshot struct {
	ID               string  `json:"id"`
	BillID           string  `json:"bill_id"`
	AmountMinorUnits int64   `json:"amount_minor_units"`
	Currency         string  `json:"currency"`
	DueDate          string  `json:"due_date"`
	PaidAt           string  `json:"paid_at"`
	Notes            *string `json:"notes"`
	CreatedAt        string  `json:"created_at"`
	UpdatedAt        string  `json:"updated_at"`
	DeletedAt        *string `json:"deleted_at"`
	Version          int     `json:"version"`
}

type paymentRecordPayload struct {
	Payment         paymentSnapshot `json:"payment"`
	Bill            billSnapshot    `json:"bill"`
	BillBaseVersion int             `json:"bill_base_version"`
}

type entityHead struct {
	version     int
	payloadJSON string
}

func (s *Store) Push(
	ctx context.Context,
	deviceID string,
	operations []PushOperation,
) ([]PushResult, error) {
	if !uuidV7Pattern.MatchString(deviceID) {
		return nil, ErrInvalidDevice
	}
	if len(operations) > MaxPushOperations {
		return nil, ErrBatchTooLarge
	}

	results := make([]PushResult, 0, len(operations))
	blocked := make(map[entityKey]bool)
	for _, operation := range operations {
		keys := affectedEntities(operation)
		if anyEntityBlocked(keys, blocked) {
			results = append(results, PushResult{
				OperationID:     operation.OperationID,
				Status:          "conflict",
				ServerSequences: []int64{},
				ErrorCode:       "prior_operation_unresolved",
			})
			continue
		}

		result, err := s.applyOperation(ctx, deviceID, operation)
		if err != nil {
			return nil, err
		}
		results = append(results, result)
		if result.Status == "conflict" || result.Status == "rejected" {
			for _, key := range keys {
				blocked[key] = true
			}
		}
	}

	return results, nil
}

func (s *Store) applyOperation(
	ctx context.Context,
	deviceID string,
	operation PushOperation,
) (PushResult, error) {
	basic, validationResult := validateBasicOperation(operation)
	if validationResult != nil {
		return *validationResult, nil
	}

	transaction, err := s.database.BeginTx(ctx, nil)
	if err != nil {
		return PushResult{}, fmt.Errorf("begin push operation: %w", err)
	}
	defer transaction.Rollback()

	stored, found, err := findStoredResult(
		ctx,
		transaction,
		deviceID,
		operation.OperationID,
		basic.payloadHash,
	)
	if err != nil {
		return PushResult{}, err
	}
	if found {
		if stored.Status == "accepted" {
			stored.Status = "duplicate"
		}
		return stored, nil
	}

	var result PushResult
	switch operation.OperationType {
	case "bill.create", "bill.update", "bill.archive":
		result, err = applyBillOperation(
			ctx,
			transaction,
			deviceID,
			operation,
			basic,
		)
	case "payment.record":
		result, err = applyPaymentRecord(
			ctx,
			transaction,
			deviceID,
			operation,
			basic,
		)
	default:
		result = rejected(operation.OperationID, "unsupported_operation")
		err = insertFinalResult(
			ctx,
			transaction,
			deviceID,
			operation.OperationID,
			basic,
			result,
		)
	}
	if err != nil {
		return PushResult{}, err
	}
	if err := transaction.Commit(); err != nil {
		return PushResult{}, fmt.Errorf("commit push operation: %w", err)
	}
	return result, nil
}

func applyBillOperation(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operation PushOperation,
	basic basicOperation,
) (PushResult, error) {
	if operation.EntityType != "bill" {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "entity_type_mismatch",
		)
	}

	var bill billSnapshot
	if err := decodeStrict(operation.Payload, &bill); err != nil {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "invalid_payload",
		)
	}
	if code := validateBill(bill); code != "" {
		return persistRejected(ctx, transaction, deviceID, operation, basic, code)
	}
	if bill.ID != operation.EntityID {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "entity_id_mismatch",
		)
	}
	if operation.OperationType == "bill.archive" && bill.Status != "archived" {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "archive_status_required",
		)
	}

	head, exists, err := findEntityHead(
		ctx,
		transaction,
		"bill",
		operation.EntityID,
	)
	if err != nil {
		return PushResult{}, err
	}
	if operation.OperationType == "bill.create" {
		if operation.BaseVersion != 0 || bill.Version != 1 {
			return persistRejected(
				ctx, transaction, deviceID, operation, basic, "invalid_version",
			)
		}
		if exists {
			return persistConflict(
				ctx, transaction, deviceID, operation, basic, "entity_exists", head.version,
			)
		}
	} else {
		if !exists {
			return persistConflict(
				ctx, transaction, deviceID, operation, basic, "entity_missing", 0,
			)
		}
		if head.version != operation.BaseVersion {
			return persistConflict(
				ctx, transaction, deviceID, operation, basic, "version_conflict", head.version,
			)
		}
		if bill.Version != operation.BaseVersion+1 {
			return persistRejected(
				ctx, transaction, deviceID, operation, basic, "invalid_version",
			)
		}
	}

	payloadJSON, _ := canonicalJSON(operation.Payload)
	updatedAtMS, _ := parseTimestamp(bill.UpdatedAt)
	deletedAtMS, _ := parseOptionalTimestamp(bill.DeletedAt)
	if err := insertPendingResult(
		ctx,
		transaction,
		deviceID,
		operation.OperationID,
		basic,
	); err != nil {
		return PushResult{}, err
	}
	if exists {
		_, err = transaction.ExecContext(
			ctx,
			`UPDATE entity_heads
			 SET version = ?, payload_json = ?, deleted_at_ms = ?, updated_at_ms = ?
			 WHERE entity_type = 'bill' AND entity_id = ?`,
			bill.Version,
			payloadJSON,
			deletedAtMS,
			updatedAtMS,
			bill.ID,
		)
	} else {
		_, err = transaction.ExecContext(
			ctx,
			`INSERT INTO entity_heads(
				entity_type, entity_id, version, payload_json, deleted_at_ms, updated_at_ms
			) VALUES ('bill', ?, ?, ?, ?, ?)`,
			bill.ID,
			bill.Version,
			payloadJSON,
			deletedAtMS,
			updatedAtMS,
		)
	}
	if err != nil {
		return PushResult{}, fmt.Errorf("write bill head: %w", err)
	}

	sequence, err := insertChange(
		ctx,
		transaction,
		operation,
		"bill",
		bill.ID,
		bill.Version,
		string(payloadJSON),
		basic.createdAtMS,
	)
	if err != nil {
		return PushResult{}, err
	}
	result := accepted(operation.OperationID, sequence)
	if err := updateStoredResult(ctx, transaction, result); err != nil {
		return PushResult{}, err
	}
	return result, nil
}

func applyPaymentRecord(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operation PushOperation,
	basic basicOperation,
) (PushResult, error) {
	if operation.EntityType != "payment" {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "entity_type_mismatch",
		)
	}
	var payload paymentRecordPayload
	if err := decodeStrict(operation.Payload, &payload); err != nil {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "invalid_payload",
		)
	}
	if code := validatePayment(payload.Payment); code != "" {
		return persistRejected(ctx, transaction, deviceID, operation, basic, code)
	}
	if code := validateBill(payload.Bill); code != "" {
		return persistRejected(ctx, transaction, deviceID, operation, basic, code)
	}
	if operation.BaseVersion != 0 || payload.Payment.Version != 1 {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "invalid_version",
		)
	}
	if payload.Payment.ID != operation.EntityID ||
		payload.Payment.BillID != payload.Bill.ID {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "entity_id_mismatch",
		)
	}
	if payload.Payment.Currency != payload.Bill.Currency {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "currency_mismatch",
		)
	}

	paymentHead, paymentExists, err := findEntityHead(
		ctx,
		transaction,
		"payment",
		payload.Payment.ID,
	)
	if err != nil {
		return PushResult{}, err
	}
	if paymentExists {
		return persistConflict(
			ctx, transaction, deviceID, operation, basic, "entity_exists", paymentHead.version,
		)
	}
	billHead, billExists, err := findEntityHead(
		ctx,
		transaction,
		"bill",
		payload.Bill.ID,
	)
	if err != nil {
		return PushResult{}, err
	}
	if !billExists {
		return persistConflict(
			ctx, transaction, deviceID, operation, basic, "bill_missing", 0,
		)
	}
	if billHead.version != payload.BillBaseVersion {
		return persistConflict(
			ctx,
			transaction,
			deviceID,
			operation,
			basic,
			"version_conflict",
			billHead.version,
		)
	}
	if payload.Bill.Version != payload.BillBaseVersion &&
		payload.Bill.Version != payload.BillBaseVersion+1 {
		return persistRejected(
			ctx, transaction, deviceID, operation, basic, "invalid_version",
		)
	}
	if payload.Bill.Version == payload.BillBaseVersion {
		storedBill, err := canonicalJSON(json.RawMessage(billHead.payloadJSON))
		if err != nil {
			return PushResult{}, fmt.Errorf("canonicalize stored bill: %w", err)
		}
		incomingBill, err := json.Marshal(payload.Bill)
		if err != nil {
			return PushResult{}, fmt.Errorf("encode incoming bill: %w", err)
		}
		incomingBill, _ = canonicalJSON(incomingBill)
		if string(storedBill) != string(incomingBill) {
			return persistRejected(
				ctx, transaction, deviceID, operation, basic, "bill_changed_without_version",
			)
		}
	}

	paymentJSON, err := json.Marshal(payload.Payment)
	if err != nil {
		return PushResult{}, fmt.Errorf("encode payment: %w", err)
	}
	billJSON, err := json.Marshal(payload.Bill)
	if err != nil {
		return PushResult{}, fmt.Errorf("encode bill: %w", err)
	}
	paymentUpdatedAtMS, _ := parseTimestamp(payload.Payment.UpdatedAt)
	paymentDeletedAtMS, _ := parseOptionalTimestamp(payload.Payment.DeletedAt)
	if err := insertPendingResult(
		ctx,
		transaction,
		deviceID,
		operation.OperationID,
		basic,
	); err != nil {
		return PushResult{}, err
	}
	if _, err := transaction.ExecContext(
		ctx,
		`INSERT INTO entity_heads(
			entity_type, entity_id, version, payload_json, deleted_at_ms, updated_at_ms
		) VALUES ('payment', ?, ?, ?, ?, ?)`,
		payload.Payment.ID,
		payload.Payment.Version,
		string(paymentJSON),
		paymentDeletedAtMS,
		paymentUpdatedAtMS,
	); err != nil {
		return PushResult{}, fmt.Errorf("write payment head: %w", err)
	}
	paymentSequence, err := insertChange(
		ctx,
		transaction,
		operation,
		"payment",
		payload.Payment.ID,
		payload.Payment.Version,
		string(paymentJSON),
		basic.createdAtMS,
	)
	if err != nil {
		return PushResult{}, err
	}
	sequences := []int64{paymentSequence}

	if payload.Bill.Version == payload.BillBaseVersion+1 {
		billUpdatedAtMS, _ := parseTimestamp(payload.Bill.UpdatedAt)
		billDeletedAtMS, _ := parseOptionalTimestamp(payload.Bill.DeletedAt)
		if _, err := transaction.ExecContext(
			ctx,
			`UPDATE entity_heads
			 SET version = ?, payload_json = ?, deleted_at_ms = ?, updated_at_ms = ?
			 WHERE entity_type = 'bill' AND entity_id = ?`,
			payload.Bill.Version,
			string(billJSON),
			billDeletedAtMS,
			billUpdatedAtMS,
			payload.Bill.ID,
		); err != nil {
			return PushResult{}, fmt.Errorf("update payment bill head: %w", err)
		}
		billSequence, err := insertChange(
			ctx,
			transaction,
			operation,
			"bill",
			payload.Bill.ID,
			payload.Bill.Version,
			string(billJSON),
			basic.createdAtMS,
		)
		if err != nil {
			return PushResult{}, err
		}
		sequences = append(sequences, billSequence)
	}

	result := PushResult{
		OperationID:     operation.OperationID,
		Status:          "accepted",
		ServerSequences: sequences,
	}
	if err := updateStoredResult(ctx, transaction, result); err != nil {
		return PushResult{}, err
	}
	return result, nil
}

func validateBasicOperation(operation PushOperation) (basicOperation, *PushResult) {
	result := rejected(operation.OperationID, "invalid_operation")
	if !uuidV7Pattern.MatchString(operation.OperationID) ||
		!uuidV7Pattern.MatchString(operation.EntityID) ||
		operation.BaseVersion < 0 {
		return basicOperation{}, &result
	}
	createdAt, err := parseTimestamp(operation.CreatedAt)
	if err != nil {
		return basicOperation{}, &result
	}
	hash, err := operationHash(operation)
	if err != nil {
		return basicOperation{}, &result
	}
	return basicOperation{
		createdAtMS: createdAt,
		payloadHash: hash,
	}, nil
}

func validateBill(bill billSnapshot) string {
	if !uuidV7Pattern.MatchString(bill.ID) || strings.TrimSpace(bill.Name) == "" {
		return "invalid_bill"
	}
	if bill.AmountMinorUnits < 0 || !validCurrency(bill.Currency) {
		return "invalid_bill"
	}
	if !oneOf(bill.BillingCycle, "one_time", "weekly", "monthly", "yearly") ||
		!oneOf(bill.Status, "active", "paused", "archived") {
		return "invalid_bill"
	}
	if _, err := time.Parse("2006-01-02", bill.NextDueDate); err != nil {
		return "invalid_bill"
	}
	if _, err := time.Parse("2006-01-02", bill.StartDate); err != nil {
		return "invalid_bill"
	}
	createdAt, err := parseTimestamp(bill.CreatedAt)
	if err != nil {
		return "invalid_bill"
	}
	updatedAt, err := parseTimestamp(bill.UpdatedAt)
	if err != nil || updatedAt < createdAt {
		return "invalid_bill"
	}
	if _, err := parseOptionalTimestamp(bill.DeletedAt); err != nil {
		return "invalid_bill"
	}
	if bill.Version < 1 {
		return "invalid_bill"
	}
	return ""
}

func validatePayment(payment paymentSnapshot) string {
	if !uuidV7Pattern.MatchString(payment.ID) ||
		!uuidV7Pattern.MatchString(payment.BillID) ||
		payment.AmountMinorUnits < 0 ||
		!validCurrency(payment.Currency) {
		return "invalid_payment"
	}
	if _, err := time.Parse("2006-01-02", payment.DueDate); err != nil {
		return "invalid_payment"
	}
	if _, err := parseTimestamp(payment.PaidAt); err != nil {
		return "invalid_payment"
	}
	createdAt, err := parseTimestamp(payment.CreatedAt)
	if err != nil {
		return "invalid_payment"
	}
	updatedAt, err := parseTimestamp(payment.UpdatedAt)
	if err != nil || updatedAt < createdAt {
		return "invalid_payment"
	}
	if _, err := parseOptionalTimestamp(payment.DeletedAt); err != nil {
		return "invalid_payment"
	}
	if payment.DeletedAt != nil || payment.Version < 1 {
		return "invalid_payment"
	}
	return ""
}

func findStoredResult(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operationID string,
	payloadHash string,
) (PushResult, bool, error) {
	var storedDeviceID string
	var storedHash string
	var resultJSON string
	err := transaction.QueryRowContext(
		ctx,
		`SELECT device_id, payload_hash, result_json
		 FROM operations WHERE operation_id = ?`,
		operationID,
	).Scan(&storedDeviceID, &storedHash, &resultJSON)
	if errors.Is(err, sql.ErrNoRows) {
		return PushResult{}, false, nil
	}
	if err != nil {
		return PushResult{}, false, fmt.Errorf("find operation result: %w", err)
	}
	if storedDeviceID != deviceID || storedHash != payloadHash {
		return rejected(operationID, "operation_id_reused"), true, nil
	}
	var result PushResult
	if err := json.Unmarshal([]byte(resultJSON), &result); err != nil {
		return PushResult{}, false, fmt.Errorf("decode operation result: %w", err)
	}
	return result, true, nil
}

func findEntityHead(
	ctx context.Context,
	transaction *sql.Tx,
	entityType string,
	entityID string,
) (entityHead, bool, error) {
	var head entityHead
	err := transaction.QueryRowContext(
		ctx,
		`SELECT version, payload_json FROM entity_heads
		 WHERE entity_type = ? AND entity_id = ?`,
		entityType,
		entityID,
	).Scan(&head.version, &head.payloadJSON)
	if errors.Is(err, sql.ErrNoRows) {
		return entityHead{}, false, nil
	}
	if err != nil {
		return entityHead{}, false, fmt.Errorf("find entity head: %w", err)
	}
	return head, true, nil
}

func insertPendingResult(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operationID string,
	basic basicOperation,
) error {
	_, err := transaction.ExecContext(
		ctx,
		`INSERT INTO operations(
			operation_id, device_id, payload_hash, result_status, result_json, created_at_ms
		) VALUES (?, ?, ?, 'accepted', '{}', ?)`,
		operationID,
		deviceID,
		basic.payloadHash,
		basic.createdAtMS,
	)
	if err != nil {
		return fmt.Errorf("insert operation: %w", err)
	}
	return nil
}

func insertFinalResult(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operationID string,
	basic basicOperation,
	result PushResult,
) error {
	resultJSON, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("encode operation result: %w", err)
	}
	_, err = transaction.ExecContext(
		ctx,
		`INSERT INTO operations(
			operation_id, device_id, payload_hash, result_status, result_json, created_at_ms
		) VALUES (?, ?, ?, ?, ?, ?)`,
		operationID,
		deviceID,
		basic.payloadHash,
		result.Status,
		string(resultJSON),
		basic.createdAtMS,
	)
	if err != nil {
		return fmt.Errorf("insert final operation result: %w", err)
	}
	return nil
}

func updateStoredResult(
	ctx context.Context,
	transaction *sql.Tx,
	result PushResult,
) error {
	resultJSON, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("encode accepted operation result: %w", err)
	}
	if _, err := transaction.ExecContext(
		ctx,
		`UPDATE operations SET result_json = ? WHERE operation_id = ?`,
		string(resultJSON),
		result.OperationID,
	); err != nil {
		return fmt.Errorf("update operation result: %w", err)
	}
	return nil
}

func persistRejected(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operation PushOperation,
	basic basicOperation,
	errorCode string,
) (PushResult, error) {
	result := rejected(operation.OperationID, errorCode)
	return result, insertFinalResult(
		ctx, transaction, deviceID, operation.OperationID, basic, result,
	)
}

func persistConflict(
	ctx context.Context,
	transaction *sql.Tx,
	deviceID string,
	operation PushOperation,
	basic basicOperation,
	errorCode string,
	currentVersion int,
) (PushResult, error) {
	result := PushResult{
		OperationID:     operation.OperationID,
		Status:          "conflict",
		ServerSequences: []int64{},
		ErrorCode:       errorCode,
		EntityType:      operation.EntityType,
		EntityID:        operation.EntityID,
		CurrentVersion:  &currentVersion,
	}
	return result, insertFinalResult(
		ctx, transaction, deviceID, operation.OperationID, basic, result,
	)
}

func insertChange(
	ctx context.Context,
	transaction *sql.Tx,
	operation PushOperation,
	entityType string,
	entityID string,
	version int,
	payloadJSON string,
	createdAtMS int64,
) (int64, error) {
	result, err := transaction.ExecContext(
		ctx,
		`INSERT INTO changes(
			operation_id, entity_type, entity_id, version, payload_json, created_at_ms
		) VALUES (?, ?, ?, ?, ?, ?)`,
		operation.OperationID,
		entityType,
		entityID,
		version,
		payloadJSON,
		createdAtMS,
	)
	if err != nil {
		return 0, fmt.Errorf("insert change: %w", err)
	}
	sequence, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("read server sequence: %w", err)
	}
	return sequence, nil
}

func operationHash(operation PushOperation) (string, error) {
	var payload any
	if err := json.Unmarshal(operation.Payload, &payload); err != nil {
		return "", err
	}
	canonical, err := json.Marshal(struct {
		EntityType    string `json:"entity_type"`
		EntityID      string `json:"entity_id"`
		OperationType string `json:"operation_type"`
		BaseVersion   int    `json:"base_version"`
		Payload       any    `json:"payload"`
		CreatedAt     string `json:"created_at"`
	}{
		EntityType:    operation.EntityType,
		EntityID:      operation.EntityID,
		OperationType: operation.OperationType,
		BaseVersion:   operation.BaseVersion,
		Payload:       payload,
		CreatedAt:     operation.CreatedAt,
	})
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(canonical)
	return hex.EncodeToString(sum[:]), nil
}

func affectedEntities(operation PushOperation) []entityKey {
	keys := []entityKey{{typeName: operation.EntityType, id: operation.EntityID}}
	if operation.OperationType == "payment.record" {
		var payload struct {
			Bill struct {
				ID string `json:"id"`
			} `json:"bill"`
		}
		if json.Unmarshal(operation.Payload, &payload) == nil && payload.Bill.ID != "" {
			keys = append(keys, entityKey{typeName: "bill", id: payload.Bill.ID})
		}
	}
	return keys
}

func anyEntityBlocked(keys []entityKey, blocked map[entityKey]bool) bool {
	for _, key := range keys {
		if blocked[key] {
			return true
		}
	}
	return false
}

func accepted(operationID string, sequences ...int64) PushResult {
	return PushResult{
		OperationID:     operationID,
		Status:          "accepted",
		ServerSequences: sequences,
	}
}

func rejected(operationID string, errorCode string) PushResult {
	return PushResult{
		OperationID:     operationID,
		Status:          "rejected",
		ServerSequences: []int64{},
		ErrorCode:       errorCode,
	}
}

func decodeStrict(data []byte, target any) error {
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var extra any
	err := decoder.Decode(&extra)
	if errors.Is(err, io.EOF) {
		return nil
	}
	if err == nil {
		return errors.New("payload memiliki lebih dari satu nilai")
	}
	return err
}

func canonicalJSON(data []byte) ([]byte, error) {
	var value any
	if err := json.Unmarshal(data, &value); err != nil {
		return nil, err
	}
	return json.Marshal(value)
}

func parseTimestamp(value string) (int64, error) {
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil || !strings.HasSuffix(value, "Z") {
		return 0, errors.New("timestamp harus RFC3339 UTC")
	}
	return parsed.UnixMilli(), nil
}

func parseOptionalTimestamp(value *string) (*int64, error) {
	if value == nil {
		return nil, nil
	}
	parsed, err := parseTimestamp(*value)
	if err != nil {
		return nil, err
	}
	return &parsed, nil
}

func validCurrency(value string) bool {
	return oneOf(value, "IDR", "USD", "EUR")
}

func oneOf(value string, allowed ...string) bool {
	for _, candidate := range allowed {
		if value == candidate {
			return true
		}
	}
	return false
}
