# Fixed Deployment Guide for Operation Won Server

## Issues Fixed
1. MySQL authentication issue - Updated default credentials in main.go to match Docker Compose
2. Added demo user with credentials:
   - Username: demo
   - Password: password123

## Deployment Steps

1. **Deploy the server**:
   ```bash
   cd /path/to/Operation-Won/server
   chmod +x deploy.sh
   ./deploy.sh
   ```

2. **When prompted to edit the .env file**:
   - Change `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` to secure values
   - Change `JWT_SECRET` to a secure random string
   - Example:
     ```
     MYSQL_ROOT_PASSWORD=your_secure_root_password
     MYSQL_PASSWORD=your_secure_user_password
     JWT_SECRET=your_secure_random_string
     ```

3. **Verify deployment**:
   - Check server health: `curl http://localhost:8000/health`
   - Check logs: `docker compose logs -f` or `podman compose logs -f`

4. **Access the application**:
   - Use the Flutter client
   - Select the appropriate server endpoint
   - Log in with demo credentials:
     - Username: demo
     - Password: password123

## Troubleshooting

If you still encounter MySQL authentication issues:

1. Check the `.env` file to ensure MySQL credentials are correct
2. Make sure the MySQL service is healthy: `docker compose ps`
3. Try restarting the containers: `docker compose restart`
4. For persistent issues, check MySQL logs: `docker compose logs mysql`
