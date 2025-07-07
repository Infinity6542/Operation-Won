package main

import (
	"github.com/golang-jwt/jwt/v5"
	"time"
	"net/http"
	"fmt"
	// "log"
	"encoding/json"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"golang.org/x/crypto/bcrypt"
)



// TODO: Make a proper implementation of JWTs
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

	token, err := jwt.Parse(token, func(token *jwt.Token) (interface{}, error) {
		return secretKey, nil
func VerifyToken(tokenString string) error {
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
	
} 
