#!/bin/bash

# Operation Won Server Test Script
# This script tests the basic functionality of the deployed server

set -e

# Add common user paths
export PATH="$HOME/.local/bin:$PATH"

echo "🧪 Operation Won Server Test Suite"
echo "=================================="

# Detect container engine and compose command
COMPOSE_CMD=""
if command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v podman &> /dev/null && podman compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="podman compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ No compatible container compose tool found"
    exit 1
fi

echo "🔧 Using compose command: $COMPOSE_CMD"

# Test if server is running
echo "🔍 Testing server health..."
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ Server health check passed"
else
    echo "❌ Server health check failed"
    exit 1
fi

# Test authentication endpoints
echo "🔍 Testing authentication endpoints..."

# Test registration
echo "📝 Testing user registration..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8000/auth/register \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","email":"test@example.com","password":"testpass123"}' \
    -w "%{http_code}")

if [[ $REGISTER_RESPONSE =~ 200$ ]] || [[ $REGISTER_RESPONSE =~ 201$ ]]; then
    echo "✅ User registration endpoint working"
elif [[ $REGISTER_RESPONSE =~ 409$ ]]; then
    echo "ℹ️  User already exists (expected in repeated tests)"
else
    echo "❌ User registration failed with response: $REGISTER_RESPONSE"
fi

# Test login
echo "🔑 Testing user login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8000/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser","password":"testpass123"}' \
    -w "%{http_code}")

if [[ $LOGIN_RESPONSE =~ 200$ ]]; then
    echo "✅ User login endpoint working"
    # Extract token for authenticated requests
    TOKEN=$(echo "$LOGIN_RESPONSE" | head -n -1 | jq -r '.token' 2>/dev/null || echo "")
else
    echo "❌ User login failed with response: $LOGIN_RESPONSE"
    TOKEN=""
fi

# Test protected endpoints if we have a token
if [ ! -z "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo "🔒 Testing protected endpoints with authentication..."
    
    # Test channels endpoint
    CHANNELS_RESPONSE=$(curl -s -X GET http://localhost:8000/channels \
        -H "Authorization: Bearer $TOKEN" \
        -w "%{http_code}")
    
    if [[ $CHANNELS_RESPONSE =~ 200$ ]]; then
        echo "✅ Channels endpoint working"
    else
        echo "❌ Channels endpoint failed with response: $CHANNELS_RESPONSE"
    fi
    
    # Test events endpoint
    EVENTS_RESPONSE=$(curl -s -X GET http://localhost:8000/events \
        -H "Authorization: Bearer $TOKEN" \
        -w "%{http_code}")
    
    if [[ $EVENTS_RESPONSE =~ 200$ ]]; then
        echo "✅ Events endpoint working"
    else
        echo "❌ Events endpoint failed with response: $EVENTS_RESPONSE"
    fi
else
    echo "⚠️  Skipping protected endpoint tests (no valid token)"
fi

# Test database connectivity
echo "🗄️  Testing database connectivity..."
if $COMPOSE_CMD exec -T mysql mysql -u root -p${MYSQL_ROOT_PASSWORD:-opwon_root_password} -e "SHOW TABLES;" operation_won &>/dev/null; then
    echo "✅ Database connection working"
else
    echo "❌ Database connection failed"
fi

# Test Redis connectivity
echo "🔴 Testing Redis connectivity..."
if $COMPOSE_CMD exec -T redis redis-cli ping &>/dev/null; then
    echo "✅ Redis connection working"
else
    echo "❌ Redis connection failed"
fi

# Test WebSocket endpoint (basic connectivity test)
echo "🔌 Testing WebSocket endpoint availability..."
WS_RESPONSE=$(curl -s -I http://localhost:8000/msg -w "%{http_code}" | tail -n1)
if [[ $WS_RESPONSE =~ 400$ ]] || [[ $WS_RESPONSE =~ 101$ ]]; then
    echo "✅ WebSocket endpoint accessible (expects WebSocket upgrade)"
else
    echo "❌ WebSocket endpoint failed with response: $WS_RESPONSE"
fi

echo ""
echo "🎉 Test suite completed!"
echo ""
echo "📊 Service Status:"
$COMPOSE_CMD ps

echo ""
echo "📋 Next steps:"
echo "  - Connect your Flutter client to http://localhost:8000"
echo "  - Use WebSocket endpoint: ws://localhost:8000/msg"
echo "  - Check logs: $COMPOSE_CMD logs -f"
echo ""
