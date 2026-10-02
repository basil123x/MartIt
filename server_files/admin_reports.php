<?php
require_once __DIR__ . '/xtras/config.php';
require_once __DIR__ . '/moderation.php';

$db = isset($conx) ? $conx : null;
if ($db === null) {
    http_response_code(500);
    echo 'Database is not configured.';
    exit;
}
martit_ensure_schema($db);

session_start();
if (isset($_POST['password'])) {
    if (hash_equals(SkDjwUc36vHy5tPC9Sf4VaHMC2VWSNFM, (string)$_POST['password'])) {
        $_SESSION['martit_admin'] = true;
    }
}
if (isset($_GET['logout'])) {
    unset($_SESSION['martit_admin']);
}

if (empty($_SESSION['martit_admin'])) {
    echo '<!doctype html><meta charset="utf-8"><title>MartIt reports</title>
    <form method="post" style="max-width:360px;margin:80px auto;font-family:sans-serif">
    <h1>MartIt reports</h1>
    <input type="password" name="password" placeholder="Admin password" style="width:100%;padding:10px" required>
    <button style="margin-top:12px;padding:10px 16px">Sign in</button></form>';
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['report_id'])) {
    $reportId = (int)$_POST['report_id'];
    $decision = $_POST['decision'] ?? '';
    $rowResult = $db->query("SELECT * FROM reports WHERE id = $reportId LIMIT 1");
    $row = $rowResult ? $rowResult->fetch_assoc() : null;
    if ($row && $decision === 'hide_product' && !empty($row['item_id'])) {
        $itemId = $db->real_escape_string($row['item_id']);
        $db->query("UPDATE Items SET Visibility = 'Hidden', status = 0 WHERE id = '$itemId'");
        $db->query("UPDATE reports SET status = 'actioned' WHERE id = $reportId");
    } elseif ($row && $decision === 'hide_comment' && !empty($row['comment_id'])) {
        $commentId = (int)$row['comment_id'];
        $db->query("DELETE FROM Comments WHERE id = $commentId");
        $db->query("UPDATE reports SET status = 'actioned' WHERE id = $reportId");
    } elseif ($row && $decision === 'ban_user' && !empty($row['target_uid'])) {
        $target = $db->real_escape_string($row['target_uid']);
        $db->query("UPDATE Users SET account_status = 'banned' WHERE uid = '$target'");
        $db->query("UPDATE Items SET Visibility = 'Hidden', status = 0 WHERE uid = '$target'");
        $db->query("UPDATE reports SET status = 'actioned' WHERE id = $reportId");
    } elseif ($decision === 'dismiss') {
        $db->query("UPDATE reports SET status = 'dismissed' WHERE id = $reportId");
    }
    header('Location: admin_reports.php');
    exit;
}

$reports = $db->query("SELECT * FROM reports ORDER BY id DESC LIMIT 200");
echo '<!doctype html><meta charset="utf-8"><title>MartIt reports</title>
<style>body{font-family:sans-serif;margin:24px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:8px;vertical-align:top}button{margin:2px}</style>
<p><a href="?logout=1">Log out</a> · Contact ' . htmlspecialchars(MARTIT_CONTACT_EMAIL) . '</p>
<h1>Reports</h1><table><tr><th>ID</th><th>Type</th><th>Reason</th><th>Note</th><th>Status</th><th></th></tr>';
if ($reports) {
    while ($report = $reports->fetch_assoc()) {
        $id = (int)$report['id'];
        echo '<tr><td>' . $id . '</td><td>' . htmlspecialchars($report['target_type'])
            . '<br>item ' . htmlspecialchars((string)$report['item_id'])
            . '<br>comment ' . htmlspecialchars((string)$report['comment_id'])
            . '<br>user ' . htmlspecialchars((string)$report['target_uid'])
            . '</td><td>' . htmlspecialchars($report['reason'])
            . '</td><td>' . htmlspecialchars((string)$report['note'])
            . '</td><td>' . htmlspecialchars($report['status']) . '</td><td>';
        if ($report['status'] === 'pending') {
            echo '<form method="post"><input type="hidden" name="report_id" value="' . $id . '">
            <button name="decision" value="hide_product">Hide product</button>
            <button name="decision" value="hide_comment">Remove comment</button>
            <button name="decision" value="ban_user">Remove user</button>
            <button name="decision" value="dismiss">Dismiss</button></form>';
        }
        echo '</td></tr>';
    }
}
echo '</table>';
