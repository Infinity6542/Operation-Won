# 🐳 Podman Setup Guide for Operation Won

This guide helps you install and configure Podman for deploying the Operation Won server.

## 🚀 Why Podman?

**Podman advantages over Docker:**
- ✅ **Rootless containers** - Better security, no root daemon
- ✅ **Daemonless** - No background service required
- ✅ **Pod support** - Native Kubernetes-style pod management
- ✅ **Drop-in replacement** - Compatible with Docker commands
- ✅ **Better security** - SELinux integration, user namespaces

## 📦 Installation

### Fedora (Recommended)
```bash
sudo dnf install podman podman-compose
```

### Ubuntu/Debian
```bash
# Add repository
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -

# Install
sudo apt-get update
sudo apt-get install podman

# Install podman-compose
pip3 install podman-compose
```

### CentOS/RHEL
```bash
sudo yum install podman podman-compose
```

### Arch Linux
```bash
sudo pacman -S podman podman-compose
```

### macOS
```bash
brew install podman podman-compose
```

## ⚙️ Configuration

### 1. Enable User Namespaces (if needed)
```bash
# Check if user namespaces are enabled
cat /proc/sys/user/max_user_namespaces

# If output is 0, enable them:
echo 'user.max_user_namespaces=28633' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 2. Configure Registries
```bash
# Create registries config
mkdir -p ~/.config/containers
cat > ~/.config/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF
```

### 3. Set up Podman Machine (macOS/Windows)
```bash
# Initialize Podman machine
podman machine init

# Start Podman machine
podman machine start

# Check status
podman machine list
```

## 🧪 Test Installation

### 1. Basic Podman Test
```bash
# Test basic functionality
podman run hello-world

# Check version
podman --version
podman-compose --version
```

### 2. Test with Operation Won
```bash
cd "/mnt/86D84B4FD84B3CA5/2. Dev/5. Operation Won/server"

# Deploy with Podman
./deploy.sh

# Should detect and use Podman automatically
```

## 🔧 Podman vs Docker Commands

| Docker Command | Podman Equivalent | Notes |
|----------------|-------------------|-------|
| `docker run` | `podman run` | Same syntax |
| `docker build` | `podman build` | Same syntax |
| `docker-compose up` | `podman-compose up` | Requires podman-compose |
| `docker ps` | `podman ps` | Same syntax |
| `docker images` | `podman images` | Same syntax |

## 🔍 Troubleshooting

### Permission Issues
```bash
# Check user setup
podman unshare cat /proc/self/uid_map

# Fix permissions if needed
podman system migrate
```

### Registry Issues
```bash
# Test registry connectivity
podman pull hello-world

# Check configured registries
podman info
```

### Storage Issues
```bash
# Check storage
podman system df

# Clean up if needed
podman system prune -a
```

### Port Binding Issues
```bash
# Check if ports are available
sudo netstat -tulpn | grep :8000

# Use different ports if needed (edit .env file)
```

## 🚀 Advanced: Rootless Deployment

For maximum security, run everything rootless:

```bash
# Enable lingering (auto-start user services)
sudo loginctl enable-linger $USER

# Deploy as regular user
cd "/mnt/86D84B4FD84B3CA5/2. Dev/5. Operation Won/server"
./deploy.sh
```

## 📊 Performance Tips

### 1. Configure Storage Driver
```bash
# Check current storage driver
podman info | grep graphDriverName

# For better performance, ensure you're using overlay
```

### 2. Optimize for Development
```bash
# Skip SELinux labeling for better performance (development only)
echo 'label=false' >> ~/.config/containers/containers.conf
```

### 3. Increase Limits
```bash
# Increase ulimits for better performance
echo 'default_ulimits = ["nofile=65536:65536"]' >> ~/.config/containers/containers.conf
```

## 🔒 Security Benefits

**Podman provides better security through:**

1. **Rootless execution** - Containers run as your user
2. **No daemon** - No privileged background process
3. **User namespaces** - Process isolation
4. **SELinux integration** - Mandatory access controls
5. **cgroups v2** - Better resource management

## 🔄 Migration from Docker

If you're migrating from Docker:

```bash
# Alias podman to docker (optional)
alias docker=podman
echo 'alias docker=podman' >> ~/.bashrc

# Import Docker images
podman load -i docker-image.tar

# Convert docker-compose.yml (works as-is with podman-compose)
```

## ✅ Verification

After installation, verify everything works:

```bash
# 1. Check Podman
podman --version
podman run hello-world

# 2. Check Compose
podman-compose --version

# 3. Deploy Operation Won
cd "/mnt/86D84B4FD84B3CA5/2. Dev/5. Operation Won/server"
./deploy.sh

# 4. Test the deployment
./test.sh
```

---

**Happy containerizing with Podman!** 🎉

For more information, visit: https://podman.io/
