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
}

func HandleRegister(w http.ResponseWriter, r *http.Request) (err error) {
	w.Header().Set("Content-Type", "application/json")

	var u User
	json.NewDecoder(r.Body).Decode(&u)	
	
	pass, err := bcrypt.GenerateFromPassword([]byte(u.Password), 14)
	if err != nil {
		fmt.Errorf("[AUT] [REG] Error while attempting to hash password", err)
	}
	fmt.Printf(string(pass))

	//TODO: Implement database integration here. For this function, also
	//      Save the login into Redis as the user is likely to try to login
}
