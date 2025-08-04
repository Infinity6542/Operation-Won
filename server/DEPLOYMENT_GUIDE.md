# Fixed Deployment Guide for Operation Won Server

## Issues Fixed
1. MySQL authentication issue - Now using consistent user credentials
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

3. **If you encounter MySQL authentication issues**:
   - Use the fix_mysql_user.sh script:
     ```bash
     chmod +x fix_mysql_user.sh
     ./fix_mysql_user.sh
     ```
   - This script will create/update the MySQL user with the password from your .env file

4. **Verify deployment**:
   - Check server health: `curl http://localhost:8000/health`
   - Check logs: `docker compose logs -f` or `podman compose logs -f`

5. **Access the application**:
   - Use the Flutter client
   - Select the appropriate server endpoint
   - Log in with demo credentials:
     - Username: demo
     - Password: password123

## Troubleshooting

If you still encounter MySQL authentication issues:

1. Verify MySQL container is running:
   ```bash
   docker ps | grep mysql
   ```

2. Check MySQL logs:
   ```bash
   docker logs opwon_mysql
   ```

3. Connect to MySQL directly to test credentials:
   ```bash
   docker exec -it opwon_mysql mysql -u opwon_user -p
   # Enter the password from your .env file when prompted
   ```

4. If you changed any credentials in .env after starting the containers:
   - Run the fix_mysql_user.sh script to sync the credentials
   - Or restart the deployment: `docker compose down && ./deploy.sh`
