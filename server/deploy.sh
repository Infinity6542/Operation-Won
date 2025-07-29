#!/bin/bash

# Operation Won Server Deployment Script
# This script sets up and deploys the Operation Won server using Podman Compose or Docker Compose

set -e

# Add common user paths
export PATH="$HOME/.local/bin:$PATH"

echo "🚀 Operation Won Server Deployment"
echo "=================================="

# Check if Podman and Podman Compose are installed, fallback to Docker
CONTAINER_ENGINE=""
COMPOSE_CMD=""

if command -v podman &> /dev/null && command -v podman-compose &> /dev/null; then
    echo "✅ Using Podman with podman-compose"
    CONTAINER_ENGINE="podman"
    COMPOSE_CMD="podman-compose"
elif command -v podman &> /dev/null && podman compose version &> /dev/null 2>&1; then
    echo "✅ Using Podman with built-in compose"
    CONTAINER_ENGINE="podman"
    COMPOSE_CMD="podman compose"
elif command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo "✅ Using Docker with docker-compose"
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    echo "✅ Using Docker with built-in compose"
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker compose"
else
    echo "❌ Neither Podman nor Docker with Compose is installed."
    echo "Please install one of the following:"
    echo "  - Podman + podman-compose: https://podman.io/"
    echo "  - Docker + Docker Compose: https://docker.com/"
    exit 1
fi

echo "🔧 Container engine: $CONTAINER_ENGINE"
echo "🔧 Compose command: $COMPOSE_CMD"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your production values!"
    echo "⚠️  Especially change the passwords and JWT secret!"
    read -p "Press enter to continue after editing .env file..."
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p ./audio
mkdir -p ./mysql_data
mkdir -p ./redis_data

# Set proper permissions
chmod 755 ./audio

# Build and start services
echo "🏗️  Building and starting services..."
$COMPOSE_CMD down
$COMPOSE_CMD build --no-cache
$COMPOSE_CMD up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
$COMPOSE_CMD ps

# Test server endpoint
echo "🧪 Testing server endpoint..."
sleep 5
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Server is running successfully!"
    echo "🌐 Server is available at: http://localhost:8000"
    echo "📊 Health check: http://localhost:8000/health"
    echo "💾 MySQL is available at: localhost:3306"
    echo "🔴 Redis is available at: localhost:6379"
else
    echo "❌ Server health check failed. Check logs:"
    $COMPOSE_CMD logs server
fi

echo ""
echo "📋 Useful commands:"
echo "  View logs: $COMPOSE_CMD logs -f"
echo "  Stop services: $COMPOSE_CMD down"
echo "  Restart services: $COMPOSE_CMD restart"
echo "  Update services: $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
echo ""
echo "🎉 Deployment complete!"
