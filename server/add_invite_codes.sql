-- Add invite codes to any events that might be missing them
-- This is a one-time migration script

USE operation_won;

-- First, let's see if there are any events without invite codes
SELECT event_uuid, event_name, invite_code FROM events WHERE invite_code IS NULL OR invite_code = '';

-- Update any events that have empty or null invite codes
-- Note: Since invite_code is NOT NULL in schema, this should only catch empty strings
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

-- Verify all events now have invite codes
SELECT event_uuid, event_name, invite_code FROM events;
