<?php
header('Content-Type: application/json');

$secretKey   = 'BML_Secret_2026';
$receivedKey = isset($_SERVER['HTTP_X_SYNC_KEY']) ? $_SERVER['HTTP_X_SYNC_KEY'] : '';

if ($receivedKey !== $secretKey) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

// Albadaa item id (client_id_badaa / idx) — NOT Globee internal item_id
$id = '';
if (isset($_POST['id']) && $_POST['id'] !== '') {
    $id = preg_replace('/[^0-9]/', '', $_POST['id']);
} elseif (isset($_GET['id']) && $_GET['id'] !== '') {
    $id = preg_replace('/[^0-9]/', '', $_GET['id']);
}

if ($id === '') {
    echo json_encode(['success' => false, 'error' => 'Missing id']);
    exit;
}

$baseDir = '/var/www/html/2026/works/stores/invoices/imgup/itmx/';

if (!is_dir($baseDir)) {
    mkdir($baseDir, 0755, true);
}

if (!isset($_FILES['upload'])) {
    echo json_encode(['success' => false, 'error' => 'No file']);
    exit;
}

$tmpName = $_FILES['upload']['tmp_name'];
$origName = $_FILES['upload']['name'];
$ext = strtolower(pathinfo($origName, PATHINFO_EXTENSION));

if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp'])) {
    echo json_encode(['success' => false, 'error' => 'Invalid file type']);
    exit;
}

$filename = $id . '.png';
$filePath = $baseDir . $filename;

$dbUpdated = false;
$dbError = null;

if (move_uploaded_file($tmpName, $filePath)) {
    require_once __DIR__ . '/xtras/config.php';

    if ($conx !== null) {
        $safeId = $conx->real_escape_string($id);
        $safeFilename = $conx->real_escape_string($filename);
        $sql = "UPDATE items SET a8 = '$safeFilename' WHERE id = '$safeId'";

        if ($conx->query($sql)) {
            $dbUpdated = $conx->affected_rows >= 0;
        } else {
            $dbError = $conx->error;
        }
    } else {
        $dbError = 'Albadaa DB connection failed';
    }

    echo json_encode([
        'success' => true,
        'url' => 'https:/bluemarinelife.com/sys2024/works/stores/invoices/imgup/itmx/' . $filename,
        'saved_to' => $filePath,
        'filename' => $filename,
        'albadaa_item_id' => $id,
        'db_updated' => $dbUpdated,
        'db_error' => $dbError,
    ]);
} else {
    $lastError = error_get_last();
    echo json_encode([
        'success' => false,
        'error' => 'Upload failed - ' . ($lastError['message'] ?? 'unknown'),
    ]);
}
