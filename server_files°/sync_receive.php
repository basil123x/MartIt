<?php
header('Content-Type: application/json');

// GET endpoint — no auth needed
if (isset($_GET['action']) && $_GET['action'] === 'get_last_id') {
    include 'xtras/config.php';
    
    // ✅ جيب الـ AUTO_INCREMENT الحقيقي مش MAX(id)
    $sql = "SELECT AUTO_INCREMENT as next_id 
            FROM information_schema.TABLES 
            WHERE TABLE_SCHEMA = DATABASE() 
            AND TABLE_NAME = 'items'";
    
    $result = $conx->query($sql);
    $next_id = 1;
    if ($result && $row = $result->fetch_assoc()) {
        $next_id = (int)$row['next_id'];
    }
    echo json_encode(['success' => true, 'last_id' => $next_id - 1, 'next_id' => $next_id]);
    exit;
}

$secretKey = 'BML_Secret_2026';
$receivedKey = isset($_SERVER['HTTP_X_SYNC_KEY']) ? $_SERVER['HTTP_X_SYNC_KEY'] : '';

if ($receivedKey !== $secretKey) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$rawData = file_get_contents('php://input');
$data = json_decode($rawData, true);

if (!$data) {
    echo json_encode(['success' => false, 'error' => 'Invalid JSON']);
    exit;
}

include 'xtras/config.php';

// insert_empty — placeholder row; returns real auto-increment id
if (isset($data['action']) && $data['action'] === 'insert_empty') {
    $sql = "INSERT INTO items (grpcon, `datex`, `uid`, branch, `status`, `status4`) VALUES (
            'items',
            NOW(),
            '0',
            'Online Sales', '0', '1')";
    if ($conx->query($sql)) {
        $realId = (int)$conx->insert_id;
        echo json_encode(['success' => true, 'id' => $realId]);
    } else {
        echo json_encode(['success' => false, 'id' => 0, 'error' => $conx->error]);
    }
    exit;
}

$a1  = isset($data['a1'])  ? $conx->real_escape_string($data['a1'])  : '';
$a3  = isset($data['a3'])  ? $conx->real_escape_string($data['a3'])  : '';
$a4  = isset($data['a4'])  ? $conx->real_escape_string($data['a4'])  : '';
$a5  = isset($data['a5'])  ? $conx->real_escape_string($data['a5'])  : '';
$a10 = isset($data['a10']) ? $conx->real_escape_string($data['a10']) : '';
$a33 = isset($data['a33']) ? (int)$data['a33'] : 0;
$explicitId = isset($data['id']) ? (int)$data['id'] : 0;


$checkSql = "SELECT id FROM items WHERE a1 = '$a1' AND a1 != '' LIMIT 1";
$checkResult = $conx->query($checkSql);

if ($checkResult && $checkResult->num_rows > 0) {
    $row = $checkResult->fetch_assoc();
    $itemId = (int)$row['id'];
    $sql = "UPDATE items SET a1='$a1', a3='$a3', a4='$a4', a5='$a5', a10='$a10', a33=$a33 WHERE id=$itemId";
    $actionTaken = 'updated';
} elseif ($explicitId > 0) {
    $itemId = $explicitId;
    $sql = "UPDATE items SET a1='$a1', a3='$a3', a4='$a4', a5='$a5', a10='$a10', a33=$a33 WHERE id=$itemId";
    $actionTaken = 'updated';
} else {
    $sql = "INSERT INTO items (a1, a3, a4, a5, a10, a33, grpcon, `datex`, `uid`, branch, `status`, `status4`) VALUES ('$a1','$a3','$a4','$a5','$a10',$a33,'itmx', NOW(), '0', 'Online Sales', '0', '1')";
    $actionTaken = 'inserted';
}

if ($conx->query($sql)) {
    $newId = ($actionTaken === 'inserted') ? (int)$conx->insert_id : $itemId;
    echo json_encode(['success' => true, 'action' => $actionTaken, 'id' => $newId]);
} else {
    echo json_encode(['success' => false, 'error' => $conx->error]);
}

?>