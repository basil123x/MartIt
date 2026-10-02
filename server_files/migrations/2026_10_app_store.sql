-- Run once on the MartIt database. Do not auto-execute from the app.
-- Safe to re-run the CREATE statements. ALTER statements fail if the column already exists;
-- moderation.php also adds the same columns with SHOW COLUMNS checks.

CREATE TABLE IF NOT EXISTS reports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  reporter_uid VARCHAR(64) NOT NULL,
  target_type VARCHAR(20) NOT NULL,
  item_id VARCHAR(64) NULL,
  comment_id VARCHAR(64) NULL,
  target_uid VARCHAR(64) NULL,
  reason VARCHAR(255) NOT NULL,
  note TEXT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  created_at DATETIME NOT NULL,
  INDEX idx_reports_status (status),
  INDEX idx_reports_item (item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS UserBlocks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  blocker_uid VARCHAR(64) NOT NULL,
  blocked_uid VARCHAR(64) NOT NULL,
  reason VARCHAR(255) NULL,
  created_at DATETIME NOT NULL,
  UNIQUE KEY uniq_block (blocker_uid, blocked_uid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add only if missing:
-- ALTER TABLE Users ADD COLUMN apple_user_id VARCHAR(128) NULL;
-- ALTER TABLE Users ADD COLUMN terms_accepted_at DATETIME NULL;
-- ALTER TABLE Users ADD COLUMN account_status VARCHAR(20) NOT NULL DEFAULT 'active';
