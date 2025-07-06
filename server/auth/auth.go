package main

import (
	"github.com/golang-jwt/jwt/v5"
	"time"
)

var secret := []byte("secret")

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

