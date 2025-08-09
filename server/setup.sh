#!/bin/bash

# setup.sh: A script to set up and run the Operation Won server environment.
# This script detects your container engine (Docker or Podman) and uses
# docker-compose to orchestrate the server, MySQL, and Redis containers.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Logic ---

# 1. Detect Container Engine and Compose Command
if command -v docker &> /dev/null; then
    info "Docker detected."
    # Check for 'docker compose' (v2) first, then fallback to 'docker-compose' (v1)
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        error "Docker is installed, but neither 'docker compose' nor 'docker-compose' was found. Please install Docker Compose."
    fi
elif command -v podman &> /dev/null; then
    info "Podman detected."
    # Podman typically uses podman-compose
    if command -v podman-compose &> /dev/null; then
        COMPOSE_CMD="podman-compose"
    else
        error "Podman is installed, but 'podman-compose' is not found. Please install it to continue."
    fi
else
    error "No container engine found. Please install Docker or Podman."
fi

info "Using '$COMPOSE_CMD' for container orchestration."

# 2. Check for docker-compose.yml
if [ ! -f "docker-compose.yml" ]; then
    error "'docker-compose.yml' not found in the current directory."
fi

# 3. Check if we need to initialize the database
info "Checking if database initialization is needed..."

# Check if MySQL volume exists and prompt user
if $COMPOSE_CMD ps mysql &> /dev/null && [ "$($COMPOSE_CMD ps mysql --format json 2>/dev/null | wc -l)" -gt 0 ]; then
    info "MySQL container already exists."
    read -p "Do you want to reset the database? This will delete all existing data. (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Stopping and removing existing containers and volumes..."
        $COMPOSE_CMD down -v
        info "Database will be reinitialized with init.sql"
    else
        info "Keeping existing database data."
    fi
fi

# 4. Build and Start Services
info "Building and starting services in the background..."
info "This might take a few minutes on the first run as images are downloaded and built."

# The 'up --build -d' command will:
# - Pull the mysql and redis images if they don't exist.
# - Build the Go server image from the Dockerfile.
# - Create and start all containers in detached mode.
$COMPOSE_CMD up --build -d

info "---"
info "✅ Server environment is up and running!"
info "The Go server should be accessible on port 8000 (or as configured)."
info "To view logs for a specific service, run: $COMPOSE_CMD logs -f <service_name>"
info "Example: $COMPOSE_CMD logs -f opwon_server"
info ""
info "To stop the services, run: $COMPOSE_CMD down"
