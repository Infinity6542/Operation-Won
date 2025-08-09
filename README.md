>[!IMPORTANT]
> 👋 **Hi there!**
> I would love to continue this project. I really do. But, as it stands, WebRTC support for Flutter isn't there yet, particularly in the documentation sector.
> At any point in the future, should the documentation and support improve, I'll come back to this project. For the time being, however, there isn't much that can be done to improve it.

# Operation Won
## Introduction
Built on the Flutter SDK, Operation Won is an app designed to transform your mobile phone into a walkie-talkie. By using Agora and Flutter Audio Service, Operation Won is designed for in-person meetings which may separate people from each other.

## Features
Operation Won is a basic, easy-to-use application, and has features such as:
- Push-to-talk (PTT) on earbuds by pausing/resuming audio stream.
- Good audio quality with low latency.
- Based off on an internet connection, allowing for an extensive range.

## Installation
For now, Operation Won can only be installed on Android via downloading and installing .apk files. This file will be provided upon the release of v1.0.0.

Unfortunately, I cannot release OpWon on iOS. If you wish to install the app on iOS, you'll have to do so on your own means via Xcode. A tutorial on this can be found [here](https://stackoverflow.com/questions/4952820/test-ios-app-on-device-without-apple-developer-program-or-jailbreak).

Operation Won is not meant for nor developed for MacOS or Windows but hey, no one's not stopping you. Simply clone the repository and run the main app. <br>
```sh
git clone https://github.com/Infinity6542/Operation-Won
```

# Contributing
Anyone is welcome to contribute to this project! All forms of contribution are greatly appreciated. To contribute, simply fork the project and create a pull request. If you wish to contribute to the website instead, you can visit [that repository](https://github.com/Infinity6542/Operation-Won-Website)

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
- Real-time notifications

### 🎉 **Event Management**
- Create and manage events
- Event-based channel organization
- User role management (organizer, member)
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
└── 📋 docs/           # Documentation and guides
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
./deploy.sh
```

This script will:
- ✅ Auto-detect Podman/Docker
- ✅ Set up environment configuration  
- ✅ Build and start all services
- ✅ Run health checks
- ✅ Display connection information

### 3. Access the Application

| Service | URL | Description |
|---------|-----|-------------|
| **API Server** | http://localhost:8000 | Backend API endpoints |
| **Health Check** | http://localhost:8000/health | Service status |
| **WebSocket** | ws://localhost:8000/msg | Real-time messaging |
| **Website** | [View Live](https://opwonweb.vercel.app/) | Official website |

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

### 🌐 **Web Interface**

The web interface is available at [opwonweb.vercel.app](https://opwonweb.vercel.app/) and provides:
- Project information and documentation
- Download links for mobile apps
- Community resources and support

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

## 🚀 Deployment

### 🐳 **Container Deployment (Recommended)**

**Option 1: Automated Script**
```bash
cd server
./deploy.sh
```

**Option 2: Manual Deployment**
```bash
# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Start with Podman (recommended)
podman-compose up -d

# OR start with Docker
docker-compose up -d
```

### ⚙️ **Production Configuration**

1. **Security Setup**
   ```bash
   # Generate secure JWT secret (32+ characters)
   openssl rand -base64 32
   
   # Update .env file
   JWT_SECRET=your_generated_secret_here
   MYSQL_PASSWORD=your_secure_database_password
   ```

2. **SSL/TLS Setup**
   - Use nginx or Traefik as reverse proxy
   - Configure SSL certificates (Let's Encrypt recommended)
   - Update CORS settings for production domains

3. **Monitoring & Logging**
   ```bash
   # View service logs
   podman-compose logs -f
   
   # Monitor container health
   podman-compose ps
   ```

### 🔍 **Health Monitoring**

```bash
# Check all services
curl http://localhost:8000/health

# View detailed status
podman-compose ps

# Check logs
podman-compose logs --tail=50 server
```

## 🤝 Contributing

We welcome contributions from the community! Here's how to get started:

### 🛠️ **Development Setup**

1. **Fork the repository**
2. **Clone your fork**
   ```bash
   git clone https://github.com/your-username/Operation-Won.git
   cd Operation-Won
   ```

3. **Set up development environment**
   ```bash
   # Backend development
   cd server
   go mod tidy
   go test
   
   # Frontend development  
   cd ../client
   flutter pub get
   flutter test
   ```

4. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

5. **Make your changes and test**
   ```bash
   # Run tests
   cd server && go test
   cd ../client && flutter test
   ```

6. **Submit a pull request**

### 📋 **Contribution Guidelines**

- **Code Style**: Follow Go and Dart formatting standards
- **Testing**: Add tests for new features
- **Documentation**: Update README and code comments
- **Security**: Follow security best practices
- **Performance**: Consider performance implications

### 🐛 **Bug Reports**

Please use GitHub Issues to report bugs with:
- Detailed description
- Steps to reproduce
- Expected vs actual behavior
- Environment information (OS, versions)
- Logs (if applicable)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Go Community** - For excellent libraries and tools
- **Flutter Team** - For the amazing cross-platform framework
- **Contributors** - Everyone who has contributed to this project
- **Open Source** - Built with and for the open source community

## 📞 Support & Community

- **📧 Issues**: [GitHub Issues](https://github.com/Infinity6542/Operation-Won/issues)
- **🌐 Website**: [opwonweb.vercel.app](https://opwonweb.vercel.app/)
- **📖 Documentation**: Available in each component's README
- **💬 Discussions**: GitHub Discussions for questions and ideas

---

**Ready to get started?** 🎉

```bash
git clone https://github.com/Infinity6542/Operation-Won.git
cd Operation-Won/server
./deploy.sh
```

Happy coding! 🚀
