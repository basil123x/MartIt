<?php
header('Content-Type: application/json');

$receivedKey = $_SERVER['HTTP_X_SYNC_KEY'] ?? '';

// ✅ قبول الاتنين
$validKeys = ['GlobalFarm_Secret_2026', 'GES_Secret_2026', 'Albadaa_Secret_2026'];
if (!in_array($receivedKey, $validKeys)) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
if (!$data || $data['action'] !== 'receive_item') {
    echo json_encode(['success' => false, 'error' => 'Invalid data']);
    exit;
}

include 'xtras/config.php';

// ✅ store_id من الداتا
$store_id = $data['store_id'] ?? '2';

// ✅ جيب uid الـ Admin حسب الـ store_id
$adminResult = $conn->query("SELECT uid FROM Users WHERE store_id = '$store_id' AND role = 'Admin' LIMIT 1");

switch ($store_id) {
	case '2':
	    $adminUid = "6356";
		break;
	case '3':
	    $adminUid = "1373";
		break;
	case '4':
	    $adminUid = "2222";
	    break;
	default:
		break;
}
if ($adminResult && $row = $adminResult->fetch_assoc()) {
    $adminUid = $row['uid'];
}

$barcode  = $conn->real_escape_string($data['barcode'] ?? '');
$name     = $conn->real_escape_string($data['name'] ?? '');
$eng      = $conn->real_escape_string($data['eng'] ?? '');
$category = $conn->real_escape_string($data['category'] ?? '');
$desc_arb = $conn->real_escape_string($data['description_arb'] ?? '');
$desc     = $conn->real_escape_string($data['description'] ?? '');
$price    = $conn->real_escape_string($data['price'] ?? '');
$qtt      = (int)($data['qtt'] ?? 0);
$clientId = (int)($data['client_id'] ?? 0);
$date     = date('Y-m-d H:i:s');

$sql = "INSERT INTO Items (barcode, name, eng, description, description_arb, category, price, qtt, idx, store_id, country, Visibility, status, created_at, uid)
        VALUES ('$barcode', '$name', '$eng', '$desc', '$desc_arb', '$category', '$price', $qtt, '$clientId', '$store_id', 'QA', 'Public', 1, '$date', '$adminUid')";

if ($conn->query($sql)) {
    echo json_encode(['success' => true, 'item_id' => $conn->insert_id]);
} else {
    echo json_encode(['success' => false, 'error' => $conn->error]);
}