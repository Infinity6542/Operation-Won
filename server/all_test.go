// main_test.go
// This file contains unit tests for the server's handlers using mocks.
// This approach removes the need for a live database connection during tests.
// Run `go get github.com/DATA-DOG/go-sqlmock` and `go get github.com/stretchr/testify` to install dependencies.
// Then run `go mod tidy` to ensure all dependencies are clean.

package main

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/go-sql-driver/mysql"
	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/assert"
	"golang.org/x/crypto/bcrypt"
)

// --- Handler Tests ---

func TestHandleRegister(t *testing.T) {
	// --- Test Case 1: Successful Registration ---
	t.Run("Successful Registration", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)
		// ADDED: Explicitly check that the db is not nil to prevent panics.
		assert.NotNil(t, server.db)

		payload := AuthPayload{
			Username: "testuser",
			Email:    "test@example.com",
			Password: "password123",
		}
		body, _ := json.Marshal(payload)

		mock.ExpectExec("INSERT INTO users").
			WithArgs(sqlmock.AnyArg(), "testuser", "test@example.com", sqlmock.AnyArg()).
			WillReturnResult(sqlmock.NewResult(1, 1))

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusCreated, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 2: Duplicate User ---
	t.Run("Duplicate User", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()
		server := NewServer(nil, db, nil)
		assert.NotNil(t, server.db)

		payload := AuthPayload{
			Username: "existinguser",
			Email:    "existing@example.com",
			Password: "password123",
		}
		body, _ := json.Marshal(payload)

		mock.ExpectExec("INSERT INTO users").
			WillReturnError(&mysql.MySQLError{Number: 1062})

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusConflict, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 3: Missing Fields ---
	t.Run("Missing Fields", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		payload := AuthPayload{Username: "testuser", Email: "test@example.com"} // Missing password
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	// --- Test Case 4: Nil Database ---
	t.Run("Nil Database", func(t *testing.T) {
		server := NewServer(nil, nil, nil)
		assert.Nil(t, server.db) // Explicitly check that the db is nil for this test case.

		payload := AuthPayload{
			Username: "testuser",
			Email:    "test@example.com",
			Password: "password123",
		}
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusInternalServerError, rr.Code)
	})
}

func TestHandleAuth(t *testing.T) {
	// --- Test Case 1: Successful Login ---
	t.Run("Successful Login", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()
		server := NewServer(nil, db, nil)
		assert.NotNil(t, server.db)

		hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
		rows := sqlmock.NewRows([]string{"id", "username", "hashed_password"}).
			AddRow(1, "testuser", string(hashedPassword))

		mock.ExpectQuery("SELECT id, username, hashed_password FROM users WHERE email = ?").
			WithArgs("test@example.com").
			WillReturnRows(rows)

		payload := AuthPayload{Email: "test@example.com", Password: "password123"}
		body, _ := json.Marshal(payload)
		req := httptest.NewRequest("POST", "/auth/login", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusOK, rr.Code)
		assert.Contains(t, rr.Body.String(), "token")
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 2: Incorrect Password ---
	t.Run("Incorrect Password", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()
		server := NewServer(nil, db, nil)
		assert.NotNil(t, server.db)

		hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("correct_password"), bcrypt.DefaultCost)
		rows := sqlmock.NewRows([]string{"id", "username", "hashed_password"}).
			AddRow(1, "testuser", string(hashedPassword))

		mock.ExpectQuery("SELECT id, username, hashed_password FROM users WHERE email = ?").
			WithArgs("test@example.com").
			WillReturnRows(rows)

		payload := AuthPayload{Email: "test@example.com", Password: "wrong_password"}
		body, _ := json.Marshal(payload)
		req := httptest.NewRequest("POST", "/auth/login", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 3: User Not Found ---
	t.Run("User Not Found", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()
		server := NewServer(nil, db, nil)
		assert.NotNil(t, server.db)

		mock.ExpectQuery("SELECT id, username, hashed_password FROM users WHERE email = ?").
			WithArgs("nouser@example.com").
			WillReturnError(sql.ErrNoRows)

		payload := AuthPayload{Email: "nouser@example.com", Password: "password123"}
		body, _ := json.Marshal(payload)
		req := httptest.NewRequest("POST", "/auth/login", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 4: Nil Database ---
	t.Run("Nil Database", func(t *testing.T) {
		server := NewServer(nil, nil, nil)
		assert.Nil(t, server.db)

		payload := AuthPayload{Email: "test@example.com", Password: "password123"}
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/auth/login", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusInternalServerError, rr.Code)
	})
}

func TestSecurity(t *testing.T) {
	// --- Test Case 1: Valid Token ---
	t.Run("Valid Token", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		// Create a test handler that the middleware will wrap
		testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			uid, ok := r.Context().Value(userIDKey).(int)
			assert.True(t, ok)
			assert.Equal(t, 1, uid)
			w.WriteHeader(http.StatusOK)
		})

		// Create a valid token
		token := createTestToken(1, "testuser")

		req := httptest.NewRequest("GET", "/protected", nil)
		req.Header.Set("auth", "Bearer "+token)
		rr := httptest.NewRecorder()

		server.Security(testHandler).ServeHTTP(rr, req)

		assert.Equal(t, http.StatusOK, rr.Code)
	})

	// --- Test Case 2: Missing Auth Header ---
	t.Run("Missing Auth Header", func(t *testing.T) {
		server := NewServer(nil, nil, nil)
		testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		req := httptest.NewRequest("GET", "/protected", nil)
		rr := httptest.NewRecorder()

		server.Security(testHandler).ServeHTTP(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
	})

	// --- Test Case 3: Invalid Token Format ---
	t.Run("Invalid Token Format", func(t *testing.T) {
		server := NewServer(nil, nil, nil)
		testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		req := httptest.NewRequest("GET", "/protected", nil)
		req.Header.Set("auth", "InvalidToken")
		rr := httptest.NewRecorder()

		server.Security(testHandler).ServeHTTP(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
	})

	// --- Test Case 4: Invalid Token ---
	t.Run("Invalid Token", func(t *testing.T) {
		server := NewServer(nil, nil, nil)
		testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		})

		req := httptest.NewRequest("GET", "/protected", nil)
		req.Header.Set("auth", "Bearer invalidtoken")
		rr := httptest.NewRecorder()

		server.Security(testHandler).ServeHTTP(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
	})
}

func TestCreateChannel(t *testing.T) {
	// --- Test Case 1: Successful Channel Creation (No Event) ---
	t.Run("Successful Channel Creation No Event", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		payload := CrtChannel{
			ChannelName: "Test Channel",
			EventUUID:   nil,
		}
		body, _ := json.Marshal(payload)

		// Mock transaction begin
		mock.ExpectBegin()
		// Mock channel creation
		mock.ExpectExec("INSERT INTO channels \\(channel_uuid, channel_name, event_id\\) VALUES \\(\\?, \\?, NULL\\)").
			WithArgs(sqlmock.AnyArg(), "Test Channel").
			WillReturnResult(sqlmock.NewResult(1, 1))
		// Mock channel member addition
		mock.ExpectExec("INSERT INTO channel_members \\(channel_id, user_id, role\\) VALUES \\(\\?, \\?, 'admin'\\)").
			WithArgs(1, 123).
			WillReturnResult(sqlmock.NewResult(1, 1))
		// Mock commit
		mock.ExpectCommit()

		req := httptest.NewRequest("POST", "/channels", bytes.NewBuffer(body))
		req = req.WithContext(context.WithValue(req.Context(), userIDKey, 123))
		rr := httptest.NewRecorder()

		server.CreateChannel(rr, req)

		assert.Equal(t, http.StatusCreated, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 2: Missing Channel Name ---
	t.Run("Missing Channel Name", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		payload := CrtChannel{
			ChannelName: "",
		}
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/channels", bytes.NewBuffer(body))
		req = req.WithContext(context.WithValue(req.Context(), userIDKey, 123))
		rr := httptest.NewRecorder()

		server.CreateChannel(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	// --- Test Case 3: Invalid JSON ---
	t.Run("Invalid JSON", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		req := httptest.NewRequest("POST", "/channels", strings.NewReader("invalid json"))
		req = req.WithContext(context.WithValue(req.Context(), userIDKey, 123))
		rr := httptest.NewRecorder()

		server.CreateChannel(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	// --- Test Case 4: Missing User Context ---
	t.Run("Missing User Context", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		payload := CrtChannel{
			ChannelName: "Test Channel",
		}
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/channels", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.CreateChannel(rr, req)

		assert.Equal(t, http.StatusInternalServerError, rr.Code)
	})
}

func TestGetChannels(t *testing.T) {
	// --- Test Case 1: Successful Channel Retrieval ---
	t.Run("Successful Channel Retrieval", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		rows := sqlmock.NewRows([]string{"channel_uuid", "channel_name", "event_uuid"}).
			AddRow("channel-uuid-1", "Channel 1", nil).
			AddRow("channel-uuid-2", "Channel 2", "event-uuid-1")

		mock.ExpectQuery("SELECT c.channel_uuid, c.channel_name, e.event_uuid FROM channels").
			WithArgs(123, 123).
			WillReturnRows(rows)

		req := httptest.NewRequest("GET", "/channels", nil)
		req = req.WithContext(context.WithValue(req.Context(), userIDKey, 123))
		rr := httptest.NewRecorder()

		server.GetChannels(rr, req)

		assert.Equal(t, http.StatusOK, rr.Code)

		var channels []ChannelResponse
		err = json.Unmarshal(rr.Body.Bytes(), &channels)
		assert.NoError(t, err)
		assert.Len(t, channels, 2)
		assert.Equal(t, "Channel 1", channels[0].ChannelName)
		assert.Nil(t, channels[0].EventUUID)
		assert.Equal(t, "Channel 2", channels[1].ChannelName)
		assert.NotNil(t, channels[1].EventUUID)

		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 2: Database Error ---
	t.Run("Database Error", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		mock.ExpectQuery("SELECT c.channel_uuid, c.channel_name, e.event_uuid FROM channels").
			WithArgs(123, 123).
			WillReturnError(sql.ErrConnDone)

		req := httptest.NewRequest("GET", "/channels", nil)
		req = req.WithContext(context.WithValue(req.Context(), userIDKey, 123))
		rr := httptest.NewRecorder()

		server.GetChannels(rr, req)

		assert.Equal(t, http.StatusInternalServerError, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}

// Helper function to create test tokens
func createTestToken(userID int, username string) string {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id":  float64(userID), // JWT numbers are float64
		"username": username,
		"exp":      9999999999, // Far future expiration
	})
	tokenString, _ := token.SignedString(secret)
	return tokenString
}

// Additional edge case tests for existing handlers
func TestHandleRegisterEdgeCases(t *testing.T) {
	// --- Test Case 1: Invalid JSON ---
	t.Run("Invalid JSON", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		req := httptest.NewRequest("POST", "/auth/register", strings.NewReader("invalid json"))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	// --- Test Case 2: Password Hashing Error (edge case) ---
	t.Run("Empty Password", func(t *testing.T) {
		server := NewServer(nil, nil, nil)

		payload := AuthPayload{
			Username: "testuser",
			Email:    "test@example.com",
			Password: "",
		}
		body, _ := json.Marshal(payload)

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
	})

	// --- Test Case 3: SQL Error Other Than Duplicate ---
	t.Run("Database Connection Error", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		payload := AuthPayload{
			Username: "testuser",
			Email:    "test@example.com",
			Password: "password123",
		}
		body, _ := json.Marshal(payload)

		mock.ExpectExec("INSERT INTO users").
			WillReturnError(sql.ErrConnDone)

		req := httptest.NewRequest("POST", "/auth/register", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleRegister(rr, req)

		assert.Equal(t, http.StatusInternalServerError, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}

func TestHandleAuthEdgeCases(t *testing.T) {
	// --- Test Case 1: Invalid JSON ---
	t.Run("Invalid JSON", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		req := httptest.NewRequest("POST", "/auth/login", strings.NewReader("invalid json"))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusBadRequest, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})

	// --- Test Case 2: Database Connection Error ---
	t.Run("Database Connection Error", func(t *testing.T) {
		db, mock, err := sqlmock.New()
		assert.NoError(t, err)
		defer db.Close()

		server := NewServer(nil, db, nil)

		payload := AuthPayload{Email: "test@example.com", Password: "password123"}
		body, _ := json.Marshal(payload)

		mock.ExpectQuery("SELECT id, username, hashed_password FROM users WHERE email = ?").
			WithArgs("test@example.com").
			WillReturnError(sql.ErrConnDone)

		req := httptest.NewRequest("POST", "/auth/login", bytes.NewBuffer(body))
		rr := httptest.NewRecorder()

		server.HandleAuth(rr, req)

		assert.Equal(t, http.StatusUnauthorized, rr.Code)
		assert.NoError(t, mock.ExpectationsWereMet())
	})
}
