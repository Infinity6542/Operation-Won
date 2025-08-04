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

# Cleanup existing network to prevent IP conflicts
echo "🧹 Cleaning up existing Docker resources..."
$COMPOSE_CMD down
if [ "$CONTAINER_ENGINE" = "docker" ]; then
    docker network ls | grep opwon_network | awk '{print $1}' | xargs -r docker network rm
    # Remove orphaned containers if any
    docker ps -a | grep "opwon_" | awk '{print $1}' | xargs -r docker rm -f
elif [ "$CONTAINER_ENGINE" = "podman" ]; then
    podman network ls | grep opwon_network | awk '{print $1}' | xargs -r podman network rm
    # Remove orphaned containers if any
    podman ps -a | grep "opwon_" | awk '{print $1}' | xargs -r podman rm -f
fi

# Build and start
$COMPOSE_CMD build --no-cache
$COMPOSE_CMD up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
$COMPOSE_CMD ps

# Verify MySQL connectivity from server container
echo "🔍 Verifying MySQL connectivity..."
if [ "$CONTAINER_ENGINE" = "docker" ]; then
    if docker exec opwon_server mysql -h mysql -u opwon_user -popwon_password -e "SELECT 1;" &>/dev/null; then
        echo "✅ MySQL connectivity verified!"
    else
        echo "⚠️ MySQL connectivity issue detected. Attempting to fix permissions..."
        docker exec opwon_mysql mysql -uroot -p${MYSQL_ROOT_PASSWORD:-opwon_root_password} -e "
            DROP USER IF EXISTS 'opwon_user'@'%';
            CREATE USER 'opwon_user'@'%' IDENTIFIED BY 'opwon_password';
            GRANT ALL PRIVILEGES ON operation_won.* TO 'opwon_user'@'%';
            FLUSH PRIVILEGES;"
        echo "🔄 Restarting server container..."
        docker restart opwon_server
        sleep 5
    fi
elif [ "$CONTAINER_ENGINE" = "podman" ]; then
    if podman exec opwon_server mysql -h mysql -u opwon_user -popwon_password -e "SELECT 1;" &>/dev/null; then
        echo "✅ MySQL connectivity verified!"
    else
        echo "⚠️ MySQL connectivity issue detected. Attempting to fix permissions..."
        podman exec opwon_mysql mysql -uroot -p${MYSQL_ROOT_PASSWORD:-opwon_root_password} -e "
            DROP USER IF EXISTS 'opwon_user'@'%';
            CREATE USER 'opwon_user'@'%' IDENTIFIED BY 'opwon_password';
            GRANT ALL PRIVILEGES ON operation_won.* TO 'opwon_user'@'%';
            FLUSH PRIVILEGES;"
        echo "🔄 Restarting server container..."
        podman restart opwon_server
        sleep 5
    fi
fi

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
echo "🖥️ Container Network Information:"
echo "  Network: 192.168.100.0/24"
echo "  MySQL: 192.168.100.2"
echo "  Redis: 192.168.100.3"
echo "  Server: 192.168.100.4"
echo ""
echo "🛠️ Troubleshooting:"
echo "  If you encounter IP conflicts, run: $COMPOSE_CMD down && $COMPOSE_CMD up -d"
echo "  For persistent issues, you may need to remove the network:"
echo "  $CONTAINER_ENGINE network rm \$($CONTAINER_ENGINE network ls | grep opwon_network | awk '{print \$1}')"
echo ""
echo "🎉 Deployment complete!"
