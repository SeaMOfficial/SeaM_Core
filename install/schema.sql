CREATE TABLE IF NOT EXISTS `seam_players` (
    `citizenid`        VARCHAR(24)  NOT NULL,
    `license`          VARCHAR(64)  NOT NULL,
    `discord`          VARCHAR(64)  DEFAULT NULL,
    `slot`             TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `name`             VARCHAR(64)  DEFAULT NULL,
    `charinfo`         LONGTEXT     DEFAULT NULL,
    `money`            LONGTEXT     DEFAULT NULL,
    `job`              LONGTEXT     DEFAULT NULL,
    `gang`             LONGTEXT     DEFAULT NULL,
    `metadata`         LONGTEXT     DEFAULT NULL,
    `position`         LONGTEXT     DEFAULT NULL,
    `permission_group` VARCHAR(24)  NOT NULL DEFAULT 'user',
    `playtime`         INT UNSIGNED NOT NULL DEFAULT 0,
    `last_seen`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `created_at`       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    UNIQUE KEY `license_slot` (`license`, `slot`),
    KEY `idx_license` (`license`),
    KEY `idx_last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `seam_transactions` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid`  VARCHAR(24)  NOT NULL,
    `account`    VARCHAR(24)  NOT NULL,
    `delta`      BIGINT       NOT NULL,
    `balance`    BIGINT       NOT NULL,
    `reason`     VARCHAR(128) DEFAULT NULL,
    `handler`    VARCHAR(64)  DEFAULT NULL,
    `actor`      VARCHAR(64)  DEFAULT NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizen_time` (`citizenid`, `created_at`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `seam_bans` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `license`    VARCHAR(64)  DEFAULT NULL,
    `discord`    VARCHAR(64)  DEFAULT NULL,
    `ip`         VARCHAR(64)  DEFAULT NULL,
    `citizenid`  VARCHAR(24)  DEFAULT NULL,
    `reason`     VARCHAR(255) NOT NULL DEFAULT 'No reason provided',
    `expires`    INT UNSIGNED DEFAULT NULL,
    `banned_by`  VARCHAR(64)  NOT NULL DEFAULT 'console',
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_license` (`license`),
    KEY `idx_discord` (`discord`),
    KEY `idx_expires` (`expires`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `seam_permissions` (
    `license`       VARCHAR(64) NOT NULL,
    `permission`    VARCHAR(24) NOT NULL DEFAULT 'user',
    `granted_by`    VARCHAR(64) NOT NULL DEFAULT 'console',
    `created_at`    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `seam_sessions` (
    `id`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(24) NOT NULL,
    `joined_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `left_at`   TIMESTAMP   NULL DEFAULT NULL,
    `duration`  INT UNSIGNED DEFAULT 0,
    `endpoint`  VARCHAR(64) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
