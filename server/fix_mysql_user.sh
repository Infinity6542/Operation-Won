#!/bin/bash

# Fix MySQL User Permissions Script
# Run this after deploy.sh if you encounter MySQL authentication issues

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "ERROR: .env file not found. Please run from the server directory."
    exit 1
fi

# Set defaults if not defined in .env
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-opwon_root_password}
MYSQL_USER=${MYSQL_USER:-opwon_user}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-opwon_password}
MYSQL_DATABASE=${MYSQL_DATABASE:-operation_won}
MYSQL_PORT=${MYSQL_PORT:-3306}

echo "🔑 Fixing MySQL user permissions..."

# Create the SQL script with the actual values from environment
cat > fix_user.sql << EOL
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
EOL

# Execute the SQL script using the MySQL container
docker exec -i opwon_mysql mysql -u root -p$MYSQL_ROOT_PASSWORD < fix_user.sql

# Check if the command was successful
if [ $? -eq 0 ]; then
    echo "✅ MySQL user '$MYSQL_USER' configured successfully!"
    echo "🔄 Restarting server container..."
    docker restart opwon_server
    echo "⏳ Waiting for server to start..."
    sleep 5
    echo "🏥 Server status:"
    docker ps | grep opwon_server
    echo "📋 Check server logs with: docker logs opwon_server"
else
    echo "❌ Failed to configure MySQL user. Check root password and try again."
    echo "📋 You may need to update your .env file with the correct passwords."
fi

# Clean up
rm fix_user.sql

echo "🎉 MySQL user fix completed!"
