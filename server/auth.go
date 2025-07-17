package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-sql-driver/mysql"
	_ "github.com/go-sql-driver/mysql"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

var secret = []byte("verymuchasecr3t")

type User struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Email string `json:"email"`
}

// TODO: Make a proper implementation of JWTs
func CreateToken(user string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256,jwt.MapClaims{
		"username": user,
		"exp": time.Now().Add(time.Hour * 24).Unix(),
	})

	tokenString, err := token.SignedString(secret)
	if err != nil {
		return "NaN", err
	}

	return tokenString, nil
}

func VerifyToken(tokenString string) error {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		return secret, nil
	})

	if err != nil {
		return err
	}

	if !token.Valid {
		return fmt.Errorf("[AUT] [TKN] Invalid token")
	}

	return nil
}

func HandleAuth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var u User
	jsonerr := json.NewDecoder(r.Body).Decode(&u)
	if jsonerr != nil {
		fmt.Println(jsonerr)
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}
	var hash string
	err := db.QueryRow("SELECT hashed_password FROM users WHERE username = ?", u.Username).Scan(&hash)
	if err != nil {
		http.Error(w, "Invalid username.", http.StatusUnauthorized)
		fmt.Printf("[AUT] [LGN] Something went wrong when searching for the user: %v", err)
		return
	}
	auth := bcrypt.CompareHashAndPassword([]byte(hash), []byte(u.Password))
	if auth != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
		fmt.Printf("[AUT] [LGN] Incorrect password for user %s", u.Username)
		return
	}

	tokenString, err := CreateToken(u.Username)
	if err != nil {
		http.Error(w, "Token creation failed", http.StatusInternalServerError)
		fmt.Printf("[AUT] [TKN] Failed to create a token for user %s: %v", u.Username, err)
		return
	}

	json.NewEncoder(w).Encode(map[string]string{
		"token": tokenString,
	})
}

func HandleRegister(w http.ResponseWriter, r *http.Request) { 
	w.Header().Set("Content-Type", "application/json")

	var u User
	defer r.Body.Close()
	err := json.NewDecoder(r.Body).Decode(&u)
	if err != nil {
		fmt.Println(err)
		http.Error(w, "Invalid body", http.StatusBadRequest)
		return
	}
	
	pass, err := bcrypt.GenerateFromPassword([]byte(u.Password), 14)
	if err != nil {
		fmt.Printf("[AUT] [REG] Error while attempting to hash password: %v", err)
		return
	}
	
	fmt.Println(u.Username, string(pass), u.Email)

	uuid := uuid.New().String()

	result, err := db.Exec("INSERT INTO users (user_uuid, username, email, hashed_password) VALUES (?, ?, ?, ?)", uuid, u.Username, u.Email, string(pass))
	if err != nil {
		fmt.Printf("[AUT] [REG] Error while adding user to the database: %v", err)
		
		code := err.(*mysql.MySQLError)

		switch code.Number {
		case 1046:
			http.Error(w, "A field was too long.", http.StatusBadRequest)
		case 1048:
			http.Error(w, "A sent value cannot be empty.", http.StatusBadRequest)
		case 1062:
			http.Error(w, "The username is not unique.", http.StatusConflict)
		default:
			http.Error(w, "An internal error occurred.", http.StatusInternalServerError)
		}
		return
	} else {
		fmt.Println(result.LastInsertId())
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Registration successful."})
}
