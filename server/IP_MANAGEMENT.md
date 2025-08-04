# IP Address Management in Docker/Podman

This document explains how we handle IP address assignments in the Operation Won project and how to troubleshoot potential conflicts.

## Static IP Configuration

The docker-compose.yml file assigns static IPs to each container:
- MySQL: 192.168.100.2
- Redis: 192.168.100.3
- Server: 192.168.100.4

The network uses a custom subnet (192.168.100.0/24) to minimize conflicts with other Docker networks.

## Troubleshooting IP Conflicts

If you encounter errors like "Address already in use" when starting containers, follow these steps:

1. Run the cleanup script to remove existing resources:
   ```
   chmod +x cleanup.sh
   ./cleanup.sh
   ```

2. Start the containers fresh:
   ```
   docker-compose up -d
   ```

3. If conflicts continue, you can modify the subnet in docker-compose.yml to use a different range, like:
   ```
   subnet: 192.168.101.0/24
   ```
   (Then update all container IP addresses accordingly)

## Common Issues

1. **"Address already in use" error**:
   This means another container or process is using the IP address. Use the cleanup script.

2. **"Failed to allocate gateway" error**:
   This typically means the network subnet conflicts with another network. Change the subnet.

3. **Connection refused between containers**:
   Ensure the containers can resolve each other's names (MySQL, Redis) or use the static IPs directly.

## Manual Network Inspection

To view network details:
```
docker network inspect opwon_network
```

To check container IP assignments:
```
docker inspect opwon_mysql | grep IPAddress
docker inspect opwon_redis | grep IPAddress
docker inspect opwon_server | grep IPAddress
```
