#!/bin/bash

# update_mysql_permissions.sql
# This SQL script is for emergency use if MySQL permissions are out of sync
# Run it with: docker exec -i opwon_mysql mysql -uroot -p < update_mysql_permissions.sql

CREATE USER IF NOT EXISTS 'opwon_user'@'%' IDENTIFIED BY 'opwon_password';
GRANT ALL PRIVILEGES ON operation_won.* TO 'opwon_user'@'%';
FLUSH PRIVILEGES;
