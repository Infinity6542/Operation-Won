# 🚀 Operation Won

**A modern real-time communication platform featuring secure authentication, event management, and instant messaging capabilities.**

Operation Won is a full-stack application consisting of a Go backend server, Flutter mobile client, and web interface, designed for seamless real-time communication and event coordination.

## 🌟 Features

### 🔐 **Authentication & Security**
- JWT-based authentication with refresh tokens
- Secure password hashing with bcrypt
- Rate limiting and brute force protection
- Redis-based session management

### 📡 **Real-Time Communication**
- WebSocket support for instant messaging
- Live audio streaming capabilities
- Push-to-talk (PTT) functionality
- [SOON] E2EE

### 🎉 **Event Management**
- Create and manage events
- Event-based channel organization
- User role management (organiser, member)
- Event discovery and participation

### 💬 **Channel System**
- Multi-channel communication
- Event-specific channels
- User permissions and moderation
- Message history and persistence

### 🏗️ **Infrastructure**
- Containerized deployment with Docker/Podman
- MySQL database with proper indexing
- Redis caching for performance
- Health monitoring and logging
- Auto-scaling ready architecture

## 📦 Architecture

```
Operation Won/
├── 🎮 client/          # Flutter mobile application
├── 🌐 website/         # Web interface and landing page
├── ⚙️  server/          # Go backend API server
│   ├── main.go         # Application entry point
│   ├── handlers.go     # HTTP request handlers
│   ├── hub.go         # WebSocket management
│   ├── utils.go       # Utility functions
│   └── all_test.go    # Comprehensive test suite
```

### 🔧 **Tech Stack**

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | Go 1.23+ | High-performance API server |
| **Database** | MySQL 8.0+ | Primary data storage |
| **Cache** | Redis 7.0+ | Session & performance cache |
| **Mobile** | Flutter 3.0+ | Cross-platform mobile app |
| **Web** | HTML5/CSS3/JS | Progressive web interface |
| **Containers** | Docker/Podman | Deployment & orchestration |
| **WebSockets** | Gorilla WebSocket | Real-time communication |
| **Auth** | JWT + bcrypt | Secure authentication |

## 🚀 Quick Start

### Prerequisites

- **Container Engine**: Podman (recommended) or Docker
- **System Requirements**: 2GB RAM, 1GB disk space
- **Network**: Ports 8000, 3306, 6379 available

### 1. Clone the Repository

```bash
git clone https://github.com/Infinity6542/Operation-Won.git
cd Operation-Won
```

### 2. Deploy the Server

```bash
cd server
podman compose up --build -d
```

### 3. Access the Application

| Service | URL | Description |
|---------|-----|-------------|
| **API Server** | http://localhost:8000 | Backend API endpoints |
| **Health Check** | http://localhost:8000/health | Service status |
| **WebSocket** | ws://localhost:8000/msg | Real-time messaging |

## 📱 Client Applications

### 🎮 **Flutter Mobile App**

```bash
cd client
flutter pub get
flutter run
```

**Features:**
- Cross-platform (iOS & Android)
- Real-time messaging
- Push notifications
- Offline capability
- Material Design UI

## 🔧 Development

### 🧪 **Testing**

The project includes a comprehensive test suite with 30+ test cases:

```bash
cd server
go test -v
```

**Test Coverage:**
- ✅ Authentication (registration, login, JWT)
- ✅ Authorization & security middleware
- ✅ Channel management (CRUD operations)
- ✅ Event management (CRUD operations)
- ✅ Database error handling
- ✅ Input validation and edge cases

### 📊 **API Documentation**

#### Authentication Endpoints
```bash
POST /auth/register    # User registration
POST /auth/login       # User authentication
POST /api/refresh      # JWT token refresh
POST /api/logout       # User logout
```

#### Protected Endpoints (require JWT)
```bash
GET  /api/protected/channels        # List user channels
POST /api/protected/channels/create # Create new channel
GET  /api/protected/events          # List user events  
POST /api/protected/events/create   # Create new event
```

#### Real-Time & Utility
```bash
GET /msg        # WebSocket connection
GET /health     # Service health check
```

### 🗄️ **Database Schema**

The application uses a relational database with the following key tables:
- `users` - User accounts and authentication
- `events` - Event information and metadata
- `channels` - Communication channels
- `event_members` - Event participation tracking
- `channel_members` - Channel access control
- `messages` - Chat message history
