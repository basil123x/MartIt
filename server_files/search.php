<?php
include 'xtras/config.php';
require_once __DIR__ . '/media_helper.php';

$searchQuery = isset($_GET['q']) ? trim($_GET['q']) : '';
$storeId = isset($_GET['store_id']) ? preg_replace('/[^0-9]/', '', $_GET['store_id']) : '';
$viewerUid = isset($_GET['viewer_uid']) ? $conx->real_escape_string(trim($_GET['viewer_uid'])) : '';

try {
    if (empty($searchQuery)) {
        echo json_encode(['success' => true, 'data' => []]);
        exit;
    }

    $searchQuery = $conx->real_escape_string($searchQuery);
    $storeClause = $storeId !== '' ? " AND Items.store_id = '$storeId'" : '';
    $blockClause = '';
    if ($viewerUid !== '') {
        $blockClause = " AND Items.uid NOT IN (SELECT blocked_uid FROM UserBlocks WHERE blocker_uid = '$viewerUid')
                         AND Users.uid NOT IN (SELECT blocked_uid FROM UserBlocks WHERE blocker_uid = '$viewerUid')
                         AND CAST(Users.id AS CHAR) NOT IN (SELECT blocked_uid FROM UserBlocks WHERE blocker_uid = '$viewerUid')";
    }

    $sql = "SELECT
        Items.id,
        Items.idx,
        Items.`name`,
        Items.price,
        Items.media,
        Items.store_id AS storeid,
        Users.Fullname,
        Users.id AS user_id,
        Users.uid AS seller_uid
    FROM Items
    LEFT JOIN Users ON Items.uid = Users.uid
    WHERE Items.Visibility = 'Public' AND Items.`name` LIKE '%$searchQuery%' $storeClause $blockClause
    ORDER BY Items.`name` ASC
    LIMIT 20";

    $result = $conx->query($sql);

    if ($result && $result->num_rows > 0) {
        $items = [];

        while ($row = $result->fetch_assoc()) {
            $storeid = !empty($row['storeid']) ? (string)$row['storeid'] : '1';
            $itemId  = (string)$row['id'];
            $idx     = (string)($row['idx'] ?? '');
            $thumbnail = item_thumbnail_url($storeid, $itemId, $idx, $row['media'] ?? null);

            $items[] = [
                'id'       => $itemId,
                'idx'      => $idx,
                'store_id' => $storeid,
                'storeid'  => $storeid,
                'name'     => $row['name'],
                'price'    => $row['price'],
                'thumbnail'=> $thumbnail,
                'seller'   => [
                    'id'   => (string)($row['user_id'] ?? ''),
                    'uid'  => (string)($row['seller_uid'] ?? ''),
                    'name' => $row['Fullname']
                ]
            ];
        }

        echo json_encode(['success' => true, 'data' => $items]);
    } else {
        echo json_encode(['success' => true, 'data' => []]);
    }

} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}

$conx->close();
?>
