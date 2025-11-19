<?php
include 'xtras/config.php';

// Get item ID parameter
$itemId = isset($_GET['item_id']) ? (int)$_GET['item_id'] : 0;

// Handle POST request for adding comments
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $comment = isset($input['comment']) ? trim($input['comment']) : '';
    $userId = isset($input['user_id']) ? (int)$input['user_id'] : 0;
    
    if (empty($comment) || $userId <= 0 || $itemId <= 0) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Invalid comment data'
        ));
        exit;
    }
    
    try {
        $comment = $conn->real_escape_string($comment);
        $sql = "INSERT INTO Comments (item_id, user_id, comment, created_at) 
                VALUES ($itemId, $userId, '$comment', NOW())";
        
        if ($conn->query($sql) === TRUE) {
            echo json_encode(array(
                'success' => true,
                'message' => 'Comment added successfully'
            ));
        } else {
            echo json_encode(array(
                'success' => false,
                'error' => 'Failed to add comment'
            ));
        }
    } catch (Exception $e) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Comment error: ' . $e->getMessage()
        ));
    }
    
    $conn->close();
    exit;
}

// Handle GET request for fetching comments
try {
    if ($itemId <= 0) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Invalid item ID'
        ));
        exit;
    }
    
    // SQL query to get comments for specific item with user details
    $sql = "SELECT
        Users.uid,
        Users.Fullname,
        Comments.`comment`,
        Comments.created_at
    FROM
        Users
    LEFT JOIN Comments
        ON Users.uid = Comments.user_id
    WHERE Comments.item_id = $itemId
    ORDER BY Comments.created_at DESC";

    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        $comments = array();
        
        while($row = $result->fetch_assoc()) {
            $comment = array(
                'id' => $row['uid'],
                'userName' => $row['Fullname'] ?: 'مستخدم',
                'userAvatar' => "https://globee.b-cdn.net/users/" . $row['uid'] . "/avatar.jpg",
                'comment' => $row['comment'],
                'createdAt' => $row['created_at']
            );
            
            $comments[] = $comment;
        }
        
        echo json_encode(array(
            'success' => true,
            'data' => $comments
        ));
        
    } else {
        echo json_encode(array(
            'success' => true,
            'data' => array()
        ));
    }
    
} catch (Exception $e) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Comments error: ' . $e->getMessage()
    ));
}

$conn->close();
?>
