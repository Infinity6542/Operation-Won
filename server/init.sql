-- Operation Won Database Initialization Script
-- This script creates the necessary tables for the Operation Won application

CREATE DATABASE IF NOT EXISTS operation_won;
USE operation_won;

-- Note: MySQL user must be created manually or by the Docker Compose
-- MySQL doesn't support environment variables in SQL directly
-- We rely on Docker Compose to create the MySQL user with correct credentials

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_uuid VARCHAR(36) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    profile_picture_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    last_seen TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_uuid (user_uuid),
    INDEX idx_username (username),
    INDEX idx_email (email)
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_uuid VARCHAR(36) UNIQUE NOT NULL,
    event_name VARCHAR(100) NOT NULL,
    event_description TEXT,
    event_link VARCHAR(255),
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    max_participants INT DEFAULT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    organiser_user_id INT NOT NULL,
    start_time TIMESTAMP NULL,
    end_time TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (organiser_user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_event_uuid (event_uuid),
    INDEX idx_invite_code (invite_code),
    INDEX idx_organiser_user_id (organiser_user_id),
    INDEX idx_start_time (start_time),
    INDEX idx_is_public (is_public)
);

-- Channels table
CREATE TABLE IF NOT EXISTS channels (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_uuid VARCHAR(36) UNIQUE NOT NULL,
    channel_name VARCHAR(100) NOT NULL,
    channel_description TEXT,
    channel_link VARCHAR(255),
    event_id INT NULL,
    max_participants INT DEFAULT NULL,
    is_public BOOLEAN DEFAULT FALSE,
    requires_approval BOOLEAN DEFAULT FALSE,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE SET NULL,
    INDEX idx_channel_uuid (channel_uuid),
    INDEX idx_event_id (event_id),
    INDEX idx_created_by (created_by),
    INDEX idx_is_public (is_public)
);

-- Messages table (for chat functionality and audio message metadata)
CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_uuid VARCHAR(36) UNIQUE NOT NULL,
    channel_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT,
    message_type ENUM('text', 'audio', 'file', 'system') DEFAULT 'text',
    audio_file_path VARCHAR(255),
    audio_duration_seconds INT DEFAULT NULL,
    file_url VARCHAR(255),
    file_name VARCHAR(255),
    file_size_bytes BIGINT DEFAULT NULL,
    reply_to_message_id INT DEFAULT NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (reply_to_message_id) REFERENCES messages(id) ON DELETE SET NULL,
    INDEX idx_message_uuid (message_uuid),
    INDEX idx_channel_id (channel_id),
    INDEX idx_user_id (user_id),
    INDEX idx_created_at (created_at),
    INDEX idx_message_type (message_type)
);

-- Channel members table (for managing channel access)
CREATE TABLE IF NOT EXISTS channel_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    channel_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('member', 'moderator', 'admin') DEFAULT 'member',
    can_speak BOOLEAN DEFAULT TRUE,
    can_mute_others BOOLEAN DEFAULT FALSE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    invited_by INT DEFAULT NULL,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY unique_channel_user (channel_id, user_id),
    INDEX idx_channel_id (channel_id),
    INDEX idx_user_id (user_id),
    INDEX idx_role (role)
);

-- Event members table (for managing event access)
CREATE TABLE IF NOT EXISTS event_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    event_id INT NOT NULL,
    user_id INT NOT NULL,
    role ENUM('participant', 'moderator', 'organiser') DEFAULT 'participant',
    attendance_status ENUM('pending', 'attending', 'not_attending', 'maybe') DEFAULT 'pending',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    invited_by INT DEFAULT NULL,
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (invited_by) REFERENCES users(id) ON DELETE SET NULL,
    UNIQUE KEY unique_event_user (event_id, user_id),
    INDEX idx_event_id (event_id),
    INDEX idx_user_id (user_id),
    INDEX idx_role (role),
    INDEX idx_attendance_status (attendance_status)
);

-- Audio sessions table (for tracking PTT sessions and recordings)
CREATE TABLE IF NOT EXISTS audio_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    session_uuid VARCHAR(36) UNIQUE NOT NULL,
    channel_id INT NOT NULL,
    speaker_user_id INT NOT NULL,
    audio_file_path VARCHAR(255),
    duration_seconds INT DEFAULT NULL,
    file_size_bytes BIGINT DEFAULT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (speaker_user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_session_uuid (session_uuid),
    INDEX idx_channel_id (channel_id),
    INDEX idx_speaker_user_id (speaker_user_id),
    INDEX idx_started_at (started_at)
);

-- Channel invites table (for managing channel invitations via links)
CREATE TABLE IF NOT EXISTS channel_invites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invite_uuid VARCHAR(36) UNIQUE NOT NULL,
    channel_id INT NOT NULL,
    created_by INT NOT NULL,
    invite_code VARCHAR(20) UNIQUE NOT NULL,
    max_uses INT DEFAULT NULL,
    uses_count INT DEFAULT 0,
    expires_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (channel_id) REFERENCES channels(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_invite_uuid (invite_uuid),
    INDEX idx_invite_code (invite_code),
    INDEX idx_channel_id (channel_id),
    INDEX idx_expires_at (expires_at),
    INDEX idx_is_active (is_active)
);

-- Event invites table (for managing event invitations via links)
CREATE TABLE IF NOT EXISTS event_invites (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invite_uuid VARCHAR(36) UNIQUE NOT NULL,
    event_id INT NOT NULL,
    created_by INT NOT NULL,
    invite_code VARCHAR(20) UNIQUE NOT NULL,
    max_uses INT DEFAULT NULL,
    uses_count INT DEFAULT 0,
    expires_at TIMESTAMP NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_invite_uuid (invite_uuid),
    INDEX idx_invite_code (invite_code),
    INDEX idx_event_id (event_id),
    INDEX idx_expires_at (expires_at),
    INDEX idx_is_active (is_active)
);

-- Create a default admin user (password: admin123)
-- Password hash for 'admin123' using bcrypt: $2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeS/FJyVbLq8T1/.S
INSERT IGNORE INTO users (user_uuid, username, email, hashed_password) VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'admin', 'admin@example.com', '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeS/FJyVbLq8T1/.S');

-- Create a demo user (password: password123)
-- Password hash for 'password123' using bcrypt: $2a$10$WO/t3NdS7LrlxLW4oM4Z1erCKnpvDuSWH9vCxO76mdNIxQ9.unvjS
INSERT IGNORE INTO users (user_uuid, username, email, hashed_password) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 'demo', 'demo@example.com', '$2a$10$WO/t3NdS7LrlxLW4oM4Z1erCKnpvDuSWH9vCxO76mdNIxQ9.unvjS');

-- Create sample data for testing
INSERT IGNORE INTO events (event_uuid, event_name, event_description, organiser_user_id, event_link, is_public, invite_code) VALUES 
('event-550e8400-e29b-41d4-a716-446655440001', 'Welcome Event', 'A welcome event for new users to learn about Operation Won', 1, 'https://operationwon.com/events/welcome', TRUE, 'ABC123');

-- Add the admin user as a member (organiser) of the welcome event
INSERT IGNORE INTO event_members (event_id, user_id, role) VALUES 
((SELECT id FROM events WHERE event_uuid = 'event-550e8400-e29b-41d4-a716-446655440001'), 1, 'organiser');

-- Add invite codes to any events that might be missing them
-- Update any events that have empty or null invite codes
UPDATE events 
SET invite_code = CONCAT(
    CHAR(65 + FLOOR(RAND() * 26)),  -- Random A-Z
    CHAR(65 + FLOOR(RAND() * 26)),  -- Random A-Z
    CHAR(65 + FLOOR(RAND() * 26)),  -- Random A-Z
    CHAR(48 + FLOOR(RAND() * 10)),  -- Random 0-9
    CHAR(48 + FLOOR(RAND() * 10)),  -- Random 0-9
    CHAR(48 + FLOOR(RAND() * 10))   -- Random 0-9
)
WHERE invite_code IS NULL OR invite_code = '';

INSERT IGNORE INTO channels (channel_uuid, channel_name, channel_description, created_by, channel_link, is_public) VALUES 
('channel-550e8400-e29b-41d4-a716-446655440001', 'General Discussion', 'Main discussion channel for general topics', 1, 'https://operationwon.com/channels/general', TRUE),
('channel-550e8400-e29b-41d4-a716-446655440002', 'Tech Talk', 'Channel for technical discussions and support', 1, 'https://operationwon.com/channels/tech', TRUE);

-- Add the admin user as a member (admin) of the default channels
INSERT IGNORE INTO channel_members (channel_id, user_id, role) VALUES 
((SELECT id FROM channels WHERE channel_uuid = 'channel-550e8400-e29b-41d4-a716-446655440001'), 1, 'admin'),
((SELECT id FROM channels WHERE channel_uuid = 'channel-550e8400-e29b-41d4-a716-446655440002'), 1, 'admin');

COMMIT;
