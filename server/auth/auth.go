package main

import (
	"github.com/golang-jwt/jwt/v5"
	"time"


var secret := []byte("secret")

// TODO: Make a proper implementation of JWTs
func createToken(user string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256,jwt.MapClaims{
		"username": user,
		"exp": time.Now().Add(time.Hour * 24).Unix(),
	})

	tokenString, err := token.SignedString(secret)
	if err != nil {
		return "NaN", err
	}

	return tokenString, nill
}

func verifyToken(token string) error {
	token, err := jwt.Parse(token, func(token *jwt.Token) (interface{}, error) {
		return secretKey, nil
	})

	if err != nil {
		return err
	}

	if !token.Valid {
		return fmt.Errorf("[AUT] [TKN] Invalid token")
	}

	return nil
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	
} 
