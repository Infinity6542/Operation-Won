-- Operation Won Database Initialization Script
-- This script creates the necessary tables for the Operation Won application

CREATE DATABASE IF NOT EXISTS operation_won;
USE operation_won;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_username (username),
    INDEX idx_email (email)
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_uuid (uuid),
    INDEX idx_created_by (created_by)
);

-- Channels table
CREATE TABLE IF NOT EXISTS channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    event_uuid VARCHAR(36),
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (event_uuid) REFERENCES events(uuid) ON DELETE SET NULL,
    INDEX idx_uuid (uuid),
    INDEX idx_event_uuid (event_uuid),
    INDEX idx_created_by (created_by)
);

-- Messages table (for chat functionality)
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_uuid VARCHAR(36) NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    message_type ENUM('text', 'audio', 'file') DEFAULT 'text',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_uuid) REFERENCES channels(uuid) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_channel_uuid (channel_uuid),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at)
);

-- Channel members table (for managing channel access)
CREATE TABLE IF NOT EXISTS channel_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_uuid VARCHAR(36) NOT NULL,
    user_id INT NOT NULL,
    role ENUM('member', 'admin', 'owner') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_uuid) REFERENCES channels(uuid) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_channel_user (channel_uuid, user_id),
    INDEX idx_channel_uuid (channel_uuid),
    INDEX idx_user_id (user_id)
);

-- Event members table (for managing event access)
CREATE TABLE IF NOT EXISTS event_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_uuid VARCHAR(36) NOT NULL,
    user_id INT NOT NULL,
    role ENUM('member', 'admin', 'owner') DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_uuid) REFERENCES events(uuid) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_event_user (event_uuid, user_id),
    INDEX idx_event_uuid (event_uuid),
    INDEX idx_user_id (user_id)
);

-- Create a default admin user (password: admin123)
-- Password hash for 'admin123' using bcrypt
INSERT IGNORE INTO users (username, email, password_hash) VALUES 
('admin', 'admin@operationwon.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeS/FJyVbLq8T1/.S');

COMMIT;
