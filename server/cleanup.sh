#!/bin/bash

# cleanup.sh
# This script helps clean up Docker/Podman resources to prevent IP conflicts

echo "🧹 Cleaning up Docker/Podman resources..."

# Determine which container engine to use
if command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker compose"
elif command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman compose"
else
    echo "❌ Neither Docker nor Podman is installed."
    exit 1
fi

# Stop and remove containers
echo "🛑 Stopping containers..."
$COMPOSE_CMD down

# Remove orphaned containers if any
echo "🗑️ Removing orphaned containers..."
$CONTAINER_CMD ps -a | grep "opwon_" | awk '{print $1}' | xargs -r $CONTAINER_CMD rm -f

# Remove the network
echo "🌐 Removing network..."
$CONTAINER_CMD network ls | grep "opwon_network" | awk '{print $1}' | xargs -r $CONTAINER_CMD network rm

# Prune unused volumes (optional, comment out if you want to keep data)
echo "📦 Cleaning up volumes..."
$CONTAINER_CMD volume prune -f

echo "✅ Cleanup complete. You can now run docker-compose up -d to start with clean resources."
