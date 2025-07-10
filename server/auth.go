package main

import (
	"github.com/golang-jwt/jwt/v5"
	"time"
	"net/http"
	"fmt"
	"encoding/json"
	_ "github.com/go-sql-driver/mysql"
	"golang.org/x/crypto/bcrypt"
)

var secret = []byte("secret")

type User struct {
		Username string `json:"username"`
		Password string `json:"password"`
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
	json.NewDecoder(r.Body).Decode(&u)
	var hash string
	err := db.QueryRow("SELECT hashed_password FROM users WHERE username = ?", u.Username).Scan(&hash)
	if err != nil {
		http.Error(w, "Invalid credentials", http.StatusUnauthorized)
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

func HandleRegister(w http.ResponseWriter, r *http.Request) (err error) {
	w.Header().Set("Content-Type", "application/json")

	var u User
	json.NewDecoder(r.Body).Decode(&u)	
	
	pass, err := bcrypt.GenerateFromPassword([]byte(u.Password), 14)
	if err != nil {
		return fmt.Errorf("[AUT] [REG] Error while attempting to hash password: %v", err)
	}

	result, err := db.Exec("INSERT INTO users (username, hashed_password) VALUES (?, ?)", u.Username, pass)
	if err != nil {
		return fmt.Errorf("[AUT] [REG] Error while adding user to the database: %v", err)
	} else {
		fmt.Println(result.LastInsertId())
	}


	//TODO: Implement database integration here. For this function, also
	//      Save the login into Redis as the user is likely to try to login
	return nil
}
