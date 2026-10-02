<?php
include 'xtras/config.php';
require_once __DIR__ . '/moderation.php';

$db = isset($conx) ? $conx : (isset($conn) ? $conn : null);
if ($db === null) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Database connection not initialized',
    ));
    exit;
}
martit_ensure_schema($db);

$itemId = isset($_GET['item_id']) ? (int)$_GET['item_id'] : 0;

function commentsJsonError($db, $message) {
    $detail = ($db && $db->error) ? $db->error : $message;
    error_log('comments.php error: ' . $detail);
    echo json_encode(array(
        'success' => false,
        'error' => $detail,
    ));
    exit;
}

// Handle POST request for adding comments
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $comment = isset($input['comment']) ? trim($input['comment']) : '';
    $userId = isset($input['user_id']) ? (int)$input['user_id'] : 0;

    if (empty($comment) || $userId <= 0 || $itemId <= 0) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Invalid comment data',
        ));
        exit;
    }

    $comment = $db->real_escape_string($comment);
    if (martit_text_has_banned_word($input['comment'])) {
        echo json_encode(array(
            'success' => false,
            'error' => 'banned_word',
        ));
        exit;
    }
    $sql = "INSERT INTO Comments (item_id, user_id, comment, created_at)
            VALUES ($itemId, $userId, '$comment', NOW())";

    if ($db->query($sql) === TRUE) {
        echo json_encode(array(
            'success' => true,
            'message' => 'Comment added successfully',
        ));
    } else {
        commentsJsonError($db, 'Failed to add comment');
    }

    $db->close();
    exit;
}

// Handle GET request for fetching comments
if ($itemId <= 0) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Invalid item ID',
    ));
    exit;
}

$viewerUid = isset($_GET['viewer_uid']) ? $db->real_escape_string($_GET['viewer_uid']) : '';
$blockSql = $viewerUid !== ''
    ? " AND Comments.user_id NOT IN (SELECT blocked_uid FROM UserBlocks WHERE blocker_uid = '$viewerUid')"
    : '';

$sql = "SELECT
    Comments.id,
    Users.uid,
    Users.Fullname,
    Comments.`comment`,
    Comments.created_at
FROM Comments
LEFT JOIN Users ON Users.id = Comments.user_id
WHERE Comments.item_id = $itemId $blockSql
ORDER BY Comments.created_at DESC";

$result = $db->query($sql);

if ($result === false) {
    commentsJsonError($db, 'Failed to load comments');
}

$comments = array();

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $comments[] = array(
            'id' => $row['id'],
            'userId' => $row['uid'] ?: '',
            'userName' => $row['Fullname'] ?: 'مستخدم',
            'userAvatar' => 'https://globee.b-cdn.net/users/' . ($row['uid'] ?: 'default') . '/avatar.jpg',
            'comment' => $row['comment'],
            'createdAt' => $row['created_at'],
        );
    }
}

echo json_encode(array(
    'success' => true,
    'data' => $comments,
));

$db->close();
