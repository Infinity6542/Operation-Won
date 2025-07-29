# Operation Won Server

A real-time communication server built with Go, featuring WebSocket support, MySQL database, and Redis caching.

## 🚀 Quick Deployment

### Prerequisites

- **Podman** (recommended) or Docker with Compose support
- At least 2GB RAM available
- Ports 8000, 3306, and 6379 available

### Supported Container Engines

The deployment scripts automatically detect and use:
1. **Podman + podman-compose** (recommended)
2. **Podman + built-in compose**
3. **Docker + docker-compose** (fallback)
4. **Docker + built-in compose** (fallback)

### One-Command Deployment

```bash
./deploy.sh
```

This script will:
1. Check for Podman/Docker installation
2. Create environment configuration
3. Build and start all services
4. Perform health checks
5. Display connection information

## 🏗️ Manual Deployment

### 1. Environment Setup

Copy the environment template:
```bash
cp .env.example .env
```

Edit `.env` with your production values:
```bash
# IMPORTANT: Change these values for production!
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_PASSWORD=your_secure_user_password
JWT_SECRET=your_very_secure_jwt_secret_key_here
```

### 2. Start Services

**With Podman:**
```bash
podman-compose up -d
# OR with built-in compose
podman compose up -d
```

**With Docker:**
```bash
docker-compose up -d
# OR with built-in compose
docker compose up -d
```

### 3. Verify Deployment

Check service status:
```bash
# Podman
podman-compose ps
# OR
podman compose ps

# Docker
docker-compose ps
# OR
docker compose ps
```

Test the server:
```bash
curl http://localhost:8000/health
```

## 📊 Services

| Service | Port | Description |
|---------|------|-------------|
| **Server** | 8000 | Go application server |
| **MySQL** | 3306 | Database server |
| **Redis** | 6379 | Cache and session storage |

## 🔌 API Endpoints

### Authentication
- `POST /auth/login` - User login
- `POST /auth/register` - User registration

### Channels
- `GET /channels` - List user channels (requires auth)
- `POST /channels/create` - Create new channel (requires auth)

### Events
- `GET /events` - List user events (requires auth)
- `POST /events/create` - Create new event (requires auth)

### WebSocket
- `GET /msg` - WebSocket connection for real-time messaging

### Health Check
- `GET /health` - Service health status

## 🛠️ Management Commands

### View Logs
```bash
# All services (Podman)
podman-compose logs -f
# OR
podman compose logs -f

# All services (Docker)
docker-compose logs -f
# OR
docker compose logs -f

# Specific service
[compose-command] logs -f server
[compose-command] logs -f mysql
[compose-command] logs -f redis
```

### Restart Services
```bash
# All services
[compose-command] restart

# Specific service
[compose-command] restart server
```

### Stop Services
```bash
[compose-command] down
```

### Update and Restart
```bash
[compose-command] down
[compose-command] build --no-cache
[compose-command] up -d
```

*Replace `[compose-command]` with your detected compose command (e.g., `podman-compose`, `podman compose`, `docker-compose`, or `docker compose`)*

## 🗄️ Database Management

### Access MySQL Container
```bash
# Podman
podman-compose exec mysql mysql -u root -p
# OR
podman compose exec mysql mysql -u root -p

# Docker
docker-compose exec mysql mysql -u root -p
# OR
docker compose exec mysql mysql -u root -p
```

### Backup Database
```bash
# Podman
podman-compose exec mysql mysqldump -u root -p operation_won > backup.sql
# Docker
docker-compose exec mysql mysqldump -u root -p operation_won > backup.sql
```

### Restore Database
```bash
# Podman
podman-compose exec -i mysql mysql -u root -p operation_won < backup.sql
# Docker
docker-compose exec -i mysql mysql -u root -p operation_won < backup.sql
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSQL_HOST` | mysql | MySQL server hostname |
| `MYSQL_PORT` | 3306 | MySQL server port |
| `MYSQL_USER` | opwon_user | MySQL username |
| `MYSQL_PASSWORD` | - | MySQL password |
| `MYSQL_DATABASE` | operation_won | MySQL database name |
| `REDIS_HOST` | redis | Redis server hostname |
| `REDIS_PORT` | 6379 | Redis server port |
| `SERVER_PORT` | 8000 | Server listening port |
| `JWT_SECRET` | - | JWT signing secret |

### Production Recommendations

1. **Change default passwords** in `.env`
2. **Use strong JWT secret** (minimum 32 characters)
3. **Set up SSL/TLS** with reverse proxy (nginx/traefik)
4. **Configure firewall** to restrict database access
5. **Set up monitoring** and log aggregation
6. **Regular backups** of MySQL data

## 🏥 Health Monitoring

### Service Health Checks

All services include health checks:
- Server: HTTP endpoint `/health`
- MySQL: `mysqladmin ping`
- Redis: `redis-cli ping`

### Monitoring Status
```bash
# Check container health
[compose-command] ps

# View health check logs
[compose-command] logs --tail=50 server
```

*Replace `[compose-command]` with your detected compose command*

## 🐛 Troubleshooting

### Common Issues

**Port already in use:**
```bash
# Check what's using the port
sudo netstat -tulpn | grep :8000
# Stop the conflicting service or change ports in .env
```

**Database connection failed:**
```bash
# Check MySQL logs
docker-compose logs mysql
# Verify credentials in .env file
```

**Redis connection failed:**
```bash
# Check Redis logs
docker-compose logs redis
# Verify Redis is running
docker-compose ps redis
```

**Server won't start:**
```bash
# Check server logs
[compose-command] logs server
# Rebuild containers
[compose-command] build --no-cache server
```

### Reset Everything
```bash
# Stop and remove all containers and volumes
[compose-command] down -v
# Remove images (Podman)
podman rmi -f $(podman images -q)
# Remove images (Docker)
docker-compose down --rmi all
# Start fresh
./deploy.sh
```

*Replace `[compose-command]` with your detected compose command*

## 📁 Project Structure

```
server/
├── main.go              # Main application entry point
├── handlers.go          # HTTP request handlers
├── utils.go             # Utility functions
├── hub.go              # WebSocket hub management
├── Dockerfile          # Container build instructions
├── docker-compose.yml  # Multi-service orchestration
├── init.sql            # Database initialization
├── deploy.sh           # Deployment script
├── .env.example        # Environment template
└── go.mod              # Go dependencies
```

## 🔒 Security Notes

- Change default passwords before production deployment
- Use environment variables for sensitive configuration
- JWT secret should be random and secure
- Consider using Docker secrets for production
- Set up proper network isolation
- Regular security updates for base images

## 📞 Support

For issues and questions:
1. Check logs with `[compose-command] logs`
2. Verify configuration in `.env`
3. Ensure all required ports are available
4. Check Podman/Docker and Compose versions

*Replace `[compose-command]` with your detected compose command*

---

**Happy coding!** 🎉

## API

### WebSocket Connection

- Connect to `ws://localhost:8080/ws`

### Message Types

- **Binary Messages**: Audio data chunks
- **Text Messages**: Control signals in JSON format, e.g., `{"type": "ptt_stop"}`

### HTTP Endpoints

- `GET /replay`: Returns the latest audio file

## Running the Server

```
go run main.go
```

The server will listen on port 8080.

## Dependencies

- gorilla/websocket: WebSocket library
- Standard Go libraries: encoding/json, log, net/http, os, sync
