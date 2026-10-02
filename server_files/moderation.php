<?php
require_once __DIR__ . '/moderation_config.php';

function martit_ensure_schema($conx) {
    $conx->query("CREATE TABLE IF NOT EXISTS reports (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $conx->query("CREATE TABLE IF NOT EXISTS UserBlocks (
        id INT AUTO_INCREMENT PRIMARY KEY,
        blocker_uid VARCHAR(64) NOT NULL,
        blocked_uid VARCHAR(64) NOT NULL,
        reason VARCHAR(255) NULL,
        created_at DATETIME NOT NULL,
        UNIQUE KEY uniq_block (blocker_uid, blocked_uid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $userColumns = array(
        'apple_user_id' => "VARCHAR(128) NULL",
        'terms_accepted_at' => "DATETIME NULL",
        'account_status' => "VARCHAR(20) NOT NULL DEFAULT 'active'",
    );
    foreach ($userColumns as $column => $definition) {
        $check = $conx->query("SHOW COLUMNS FROM Users LIKE '$column'");
        if ($check && $check->num_rows === 0) {
            $conx->query("ALTER TABLE Users ADD COLUMN $column $definition");
        }
    }
}

function martit_block_clause($conx, $viewerUid) {
    $viewerUid = $conx->real_escape_string(trim((string)$viewerUid));
    if ($viewerUid === '') {
        return '';
    }
    // Hide only the blocked account. A NULL blocked_uid would make NOT IN
    // drop every row, and the viewer's own items are never part of the block.
    return " AND (Items.uid = '$viewerUid' OR Items.uid NOT IN (
        SELECT blocked_uid FROM UserBlocks
        WHERE blocker_uid = '$viewerUid'
          AND blocked_uid IS NOT NULL
          AND blocked_uid <> ''
          AND blocked_uid <> '$viewerUid'
    )) AND (Users.account_status IS NULL OR Users.account_status <> 'banned' OR Items.uid = '$viewerUid')";
}

function martit_add_report($conx) {
    $itemId = $conx->real_escape_string($_POST['item_id'] ?? '');
    $userId = $conx->real_escape_string($_POST['user_id'] ?? '');
    $reason = $conx->real_escape_string($_POST['reason'] ?? '');
    $note = $conx->real_escape_string($_POST['note'] ?? '');
    $targetType = $conx->real_escape_string($_POST['target_type'] ?? 'product');
    $commentId = $conx->real_escape_string($_POST['comment_id'] ?? '');
    $targetUid = $conx->real_escape_string($_POST['target_uid'] ?? '');
    $createdAt = date('Y-m-d H:i:s');

    if ($userId === '' || $reason === '') {
        return array('success' => false, 'error' => 'reporter and reason are required');
    }
    if ($targetType === 'product' && $itemId === '') {
        return array('success' => false, 'error' => 'item_id is required');
    }
    if ($targetType === 'comment' && $commentId === '') {
        return array('success' => false, 'error' => 'comment_id is required');
    }

    $sql = "INSERT INTO reports (reporter_uid, target_type, item_id, comment_id, target_uid, reason, note, status, created_at)
            VALUES ('$userId', '$targetType', " . ($itemId === '' ? "NULL" : "'$itemId'") . ",
                    " . ($commentId === '' ? "NULL" : "'$commentId'") . ",
                    " . ($targetUid === '' ? "NULL" : "'$targetUid'") . ",
                    '$reason', " . ($note === '' ? "NULL" : "'$note'") . ", 'pending', '$createdAt')";
    if (!$conx->query($sql)) {
        return array('success' => false, 'error' => 'failed to save report');
    }

    if ($itemId !== '' && $targetType === 'product') {
        $conx->query("INSERT INTO Flags (item_id, user_id, reason, created_at, status)
                      VALUES ('$itemId', '$userId', '$reason', '$createdAt', 'pending')");
    }

    return array('success' => true, 'message' => 'reported');
}

function martit_private_dir() {
    if (!defined('MARTIT_PRIVATE_DIR')) {
        $privateDir = getenv('MARTIT_PRIVATE_DIR');
        define(
            'MARTIT_PRIVATE_DIR',
            (is_string($privateDir) && $privateDir !== '') ? $privateDir : '/home/mart-it.store/private'
        );
    }
    return rtrim(MARTIT_PRIVATE_DIR, '/');
}

function martit_delete_log($message) {
    $dir = martit_private_dir();
    if (!is_dir($dir)) {
        @mkdir($dir, 0700, true);
    }
    $safe = preg_replace(
        '/(client_secret|refresh_token|access_token|id_token|authorization_code|apple_authorization_code)["\s:=]+[^,\s}"]+/i',
        '$1=[redacted]',
        (string)$message
    );
    @file_put_contents($dir . '/account_delete.log', date('c') . ' ' . $safe . "\n", FILE_APPEND | LOCK_EX);
}

function martit_sql_ident($name) {
    return preg_match('/^[A-Za-z0-9_]+$/', (string)$name) === 1;
}

function martit_delete_reference_map($conx) {
    $wanted = array(
        'uid', 'user_id', 'cust_id', 'buyer_id', 'sender_id', 'receiver_id', 'seller_id',
        'blocker_uid', 'blocked_uid', 'reporter_uid', 'target_uid', 'oid',
    );
    $in = "'" . implode("','", $wanted) . "'";
    $sql = "SELECT c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE
            FROM information_schema.COLUMNS c
            INNER JOIN information_schema.TABLES t
                ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
            WHERE c.TABLE_SCHEMA = DATABASE()
              AND t.TABLE_TYPE = 'BASE TABLE'
              AND c.TABLE_NAME <> 'Users'
              AND c.COLUMN_NAME IN ($in)";
    $result = $conx->query($sql);
    $map = array();
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $table = (string)$row['TABLE_NAME'];
            $column = (string)$row['COLUMN_NAME'];
            if (!martit_sql_ident($table) || !martit_sql_ident($column)) {
                continue;
            }
            if (!isset($map[$table])) {
                $map[$table] = array();
            }
            $map[$table][$column] = strtolower((string)$row['DATA_TYPE']);
        }
        return $map;
    }

    martit_delete_log('information_schema failed');
    $fallback = array(
        'Comments' => array('user_id'),
        'Likes' => array('user_id'),
        'Followers' => array('user_id', 'buyer_id'),
        'Cart' => array('user_id'),
        'UserBlocks' => array('blocker_uid', 'blocked_uid'),
        'reports' => array('reporter_uid', 'target_uid'),
        'Flags' => array('user_id'),
        'NotifyRequests' => array('user_id'),
        'UserInteractions' => array('user_id'),
        'UserCategoryScore' => array('user_id'),
        'Shipping_Orders' => array('uid', 'oid'),
        'Orders' => array('uid', 'cust_id', 'oid'),
        'Chat_Messages' => array('sender_id', 'receiver_id', 'seller_id'),
        'Items' => array('uid'),
        'Transactions' => array('oid'),
    );
    $map = array();
    foreach ($fallback as $table => $columns) {
        if (!martit_sql_ident($table)) {
            continue;
        }
        $exists = $conx->query("SHOW TABLES LIKE '" . $conx->real_escape_string($table) . "'");
        if (!$exists || $exists->num_rows === 0) {
            continue;
        }
        $map[$table] = array();
        foreach ($columns as $column) {
            $map[$table][$column] = 'varchar';
        }
        $described = $conx->query("SHOW COLUMNS FROM `$table`");
        if ($described) {
            while ($field = $described->fetch_assoc()) {
                $fieldName = (string)$field['Field'];
                if (!isset($map[$table][$fieldName])) {
                    continue;
                }
                $type = strtolower((string)$field['Type']);
                $map[$table][$fieldName] = preg_replace('/\(.*/', '', $type);
            }
        }
    }
    return $map;
}

function martit_delete_account($conx, $uid) {
    $postedUid = trim((string)$uid);
    martit_delete_log('request received uid=' . ($postedUid === '' ? '(empty)' : $postedUid));
    if ($postedUid === '') {
        return array('success' => false, 'error' => 'uid is required');
    }

    $uidEsc = $conx->real_escape_string($postedUid);
    $userWhere = "uid = '$uidEsc'";
    if (ctype_digit($postedUid)) {
        $userWhere .= " OR id = '$uidEsc'";
    }
    $userResult = $conx->query(
        "SELECT id, uid, oid, login_type, apple_user_id FROM Users WHERE $userWhere LIMIT 1"
    );
    $user = $userResult ? $userResult->fetch_assoc() : null;
    if (!$user) {
        martit_delete_log('user already absent');
        return array(
            'success' => true,
            'message' => 'account deleted',
            'already_deleted' => true,
            'media' => array(),
        );
    }

    $canonicalUid = trim((string)($user['uid'] ?? ''));
    $numericId = trim((string)($user['id'] ?? ''));
    $userOid = trim((string)($user['oid'] ?? ''));
    if ($canonicalUid === '') {
        $canonicalUid = $postedUid;
    }

    if (strtolower((string)($user['login_type'] ?? '')) === 'apple') {
        $appleRevoke = martit_private_dir() . '/apple_revoke.php';
        if (is_file($appleRevoke)) {
            require_once $appleRevoke;
        }
        $postedAppleId = trim((string)($_POST['apple_user_id'] ?? ''));
        $authorizationCode = trim((string)($_POST['apple_authorization_code'] ?? ''));
        $storedAppleId = trim((string)($user['apple_user_id'] ?? ''));
        $identityOk = $postedAppleId !== '' && $storedAppleId !== '' && hash_equals($storedAppleId, $postedAppleId);
        martit_delete_log('identity check ' . ($identityOk ? 'match' : 'mismatch'));
        if (!$identityOk) {
            http_response_code(403);
            return array('success' => false, 'error' => 'apple_identity_mismatch');
        }
        if ($authorizationCode === '' || !function_exists('martit_apple_revoke_authorization_code')) {
            martit_delete_log('revoke result http=0 apple_error=missing_code_or_helper');
            http_response_code(409);
            return array('success' => false, 'error' => 'apple_revoke_failed');
        }
        try {
            $revoke = martit_apple_revoke_authorization_code($authorizationCode);
        } catch (Throwable $e) {
            martit_delete_log('revoke result http=0 apple_error=exception');
            http_response_code(409);
            return array('success' => false, 'error' => 'apple_revoke_failed');
        }
        $revokeStatus = isset($revoke['http_status']) ? (int)$revoke['http_status'] : 0;
        $revokeError = isset($revoke['error']) ? preg_replace('/[^A-Za-z0-9_]/', '', (string)$revoke['error']) : '';
        martit_delete_log('revoke result http=' . $revokeStatus . ' apple_error=' . $revokeError);
        if (empty($revoke['ok'])) {
            http_response_code(409);
            return array('success' => false, 'error' => 'apple_revoke_failed');
        }
    } else {
        martit_delete_log('identity check not_apple');
    }

    $uidMatch = $conx->real_escape_string($canonicalUid);
    $idMatch = $conx->real_escape_string($numericId);
    $oidMatch = $conx->real_escape_string($userOid);
    $integerTypes = array('int', 'bigint', 'smallint', 'tinyint', 'mediumint');

    $media = array();
    $items = $conx->query("SELECT id, media FROM Items WHERE uid = '$uidMatch'");
    if ($items) {
        while ($row = $items->fetch_assoc()) {
            $raw = (string)($row['media'] ?? '');
            foreach (preg_split('/\s*,\s*/', $raw) as $part) {
                $part = trim($part);
                if ($part !== '') {
                    $media[] = $part;
                }
            }
        }
    }
    $media[] = "Users/store_1/$canonicalUid/1.webp";

    $conx->query('SET FOREIGN_KEY_CHECKS=0');
    $tables = martit_delete_reference_map($conx);
    foreach ($tables as $table => $columns) {
        $where = array();
        foreach ($columns as $column => $dataType) {
            if (!martit_sql_ident($column)) {
                continue;
            }
            $isInt = in_array($dataType, $integerTypes, true);
            if ($column === 'oid') {
                if ($userOid !== '' && !$isInt) {
                    $where[] = "`$column` = '$oidMatch'";
                } elseif ($userOid !== '' && $isInt && ctype_digit($userOid)) {
                    $where[] = "`$column` = '$oidMatch'";
                }
                continue;
            }
            if ($isInt) {
                if ($numericId !== '' && ctype_digit($numericId)) {
                    $where[] = "`$column` = '$idMatch'";
                }
                if (ctype_digit($canonicalUid) && $canonicalUid !== $numericId) {
                    $where[] = "`$column` = '$uidMatch'";
                }
                continue;
            }
            $where[] = "`$column` = '$uidMatch'";
            if ($numericId !== '' && $numericId !== $canonicalUid) {
                $where[] = "`$column` = '$idMatch'";
            }
        }
        if (empty($where)) {
            martit_delete_log('table ' . $table . ' rows=0');
            continue;
        }
        $ok = $conx->query("DELETE FROM `$table` WHERE " . implode(' OR ', $where));
        if ($ok) {
            martit_delete_log('table ' . $table . ' rows=' . (int)$conx->affected_rows);
        } else {
            martit_delete_log('table ' . $table . ' rows=failed');
        }
    }

    $userSql = "DELETE FROM Users WHERE uid = '$uidMatch'";
    if ($numericId !== '' && ctype_digit($numericId)) {
        $userSql .= " OR id = '$idMatch'";
    }
    $userDeleted = $conx->query($userSql);
    $userRows = $userDeleted ? (int)$conx->affected_rows : -1;
    martit_delete_log('table Users rows=' . $userRows);
    $conx->query('SET FOREIGN_KEY_CHECKS=1');
    if (!$userDeleted) {
        return array('success' => false, 'error' => 'failed to delete user');
    }

    return array(
        'success' => true,
        'message' => 'account deleted',
        'media' => array_values(array_unique($media)),
    );
}

function martit_handle_action($conx, $action) {
    switch ($action) {
        case 'verify_reviewer_phone':
            if (!MARTIT_DEMO_LOGIN_ENABLED) {
                return array('success' => false, 'error' => 'invalid');
            }
            $phone = martit_digits($_POST['phone'] ?? '');
            $code = trim((string)($_POST['code'] ?? ''));
            if ($phone === '' || $code === '' || !martit_demo_phone_matches($phone) || !hash_equals(MARTIT_DEMO_CODE, $code)) {
                return array('success' => false, 'error' => 'invalid');
            }
            $demoUid = $conx->real_escape_string(MARTIT_DEMO_UID);
            $result = $conx->query("SELECT uid, oid, Fullname, Email, Phone FROM Users WHERE uid = '$demoUid' LIMIT 1");
            $user = $result ? $result->fetch_assoc() : null;
            if (!$user) {
                return array('success' => false, 'error' => 'demo account is not installed');
            }
            return array(
                'success' => true,
                'data' => array(
                    'id' => (string)$user['uid'],
                    'oid' => (string)($user['oid'] ?? ''),
                    'name' => (string)($user['Fullname'] ?? 'Demo'),
                    'email' => (string)($user['Email'] ?? ''),
                    'phone' => (string)($user['Phone'] ?? ''),
                ),
            );

        case 'get_user_by_apple_id':
            $appleId = $conx->real_escape_string($_POST['apple_user_id'] ?? '');
            if ($appleId === '') {
                return array('success' => false, 'error' => 'missing apple id');
            }
            $result = $conx->query("SELECT uid, oid, Fullname, Email FROM Users WHERE apple_user_id = '$appleId' LIMIT 1");
            $user = $result ? $result->fetch_assoc() : null;
            if (!$user) {
                return array('success' => false, 'error' => 'not found');
            }
            return array(
                'success' => true,
                'data' => array(
                    'id' => (string)$user['uid'],
                    'oid' => (string)($user['oid'] ?? ''),
                    'name' => (string)($user['Fullname'] ?? ''),
                    'email' => (string)($user['Email'] ?? ''),
                ),
            );

        case 'link_apple_id':
            $appleId = $conx->real_escape_string($_POST['apple_user_id'] ?? '');
            $email = $conx->real_escape_string($_POST['email'] ?? '');
            if ($appleId === '' || $email === '') {
                return array('success' => false, 'error' => 'missing fields');
            }
            $conx->query("UPDATE Users SET apple_user_id = '$appleId' WHERE Email = '$email' LIMIT 1");
            return array('success' => true);

        case 'accept_terms':
            $uid = $conx->real_escape_string($_POST['uid'] ?? '');
            if ($uid === '') {
                return array('success' => false, 'error' => 'uid is required');
            }
            $now = date('Y-m-d H:i:s');
            if (!$conx->query("UPDATE Users SET terms_accepted_at = '$now' WHERE uid = '$uid'")) {
                return array('success' => false, 'error' => 'failed to store acceptance');
            }
            return array('success' => true, 'accepted_at' => $now);

        case 'block_user':
            $blocker = $conx->real_escape_string($_POST['blocker_uid'] ?? '');
            $blocked = $conx->real_escape_string($_POST['blocked_uid'] ?? '');
            $reason = $conx->real_escape_string($_POST['reason'] ?? '');
            if ($blocker === '' || $blocked === '' || $blocker === $blocked) {
                return array('success' => false, 'error' => 'invalid users');
            }
            $now = date('Y-m-d H:i:s');
            $sql = "INSERT INTO UserBlocks (blocker_uid, blocked_uid, reason, created_at)
                    VALUES ('$blocker', '$blocked', '$reason', '$now')
                    ON DUPLICATE KEY UPDATE reason = '$reason', created_at = '$now'";
            if (!$conx->query($sql)) {
                return array('success' => false, 'error' => 'failed to block');
            }
            return array('success' => true);

        case 'unblock_user':
            $blocker = $conx->real_escape_string($_POST['blocker_uid'] ?? '');
            $blocked = $conx->real_escape_string($_POST['blocked_uid'] ?? '');
            $conx->query("DELETE FROM UserBlocks WHERE blocker_uid = '$blocker' AND blocked_uid = '$blocked'");
            return array('success' => true);

        case 'get_blocked_users':
            $blocker = $conx->real_escape_string($_POST['blocker_uid'] ?? '');
            $rows = array();
            $result = $conx->query("SELECT UserBlocks.blocked_uid, UserBlocks.created_at, Users.Fullname, Users.id AS user_id
                                    FROM UserBlocks
                                    LEFT JOIN Users ON Users.uid = UserBlocks.blocked_uid OR Users.id = UserBlocks.blocked_uid
                                    WHERE UserBlocks.blocker_uid = '$blocker'
                                    ORDER BY UserBlocks.created_at DESC");
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    $rows[] = array(
                        'uid' => (string)$row['blocked_uid'],
                        'id' => (string)($row['user_id'] ?? ''),
                        'name' => (string)($row['Fullname'] ?? $row['blocked_uid']),
                        'created_at' => (string)$row['created_at'],
                    );
                }
            }
            return array('success' => true, 'data' => $rows);

        case 'check_banned_words':
            $text = $_POST['text'] ?? '';
            if (martit_text_has_banned_word($text)) {
                return array('success' => false, 'error' => 'banned_word');
            }
            return array('success' => true);

        default:
            return null;
    }
}
