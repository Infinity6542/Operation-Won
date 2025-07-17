package main

import (
	"database/sql"
	"github.com/redis/go-redis/v9"
	"github.com/go-sql-driver/mysql"
)

type Server struct {
	hub *Hub
	db *sql.DB
	redis *redis.Client
}
