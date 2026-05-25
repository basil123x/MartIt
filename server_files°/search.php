<?php
include 'xtras/config.php';
require_once __DIR__ . '/media_helper.php';

// Get search query parameter
$searchQuery = isset($_GET['q']) ? trim($_GET['q']) : '';
$storeId = isset($_GET['store_id']) ? preg_replace('/[^0-9]/', '', $_GET['store_id']) : '';

try {
    if (empty($searchQuery)) {
        echo json_encode(array(
            'success' => true,
            'data' => array()
        ));
        exit;
    }
    
    $searchQuery = $conx->real_escape_string($searchQuery);
    $storeClause = $storeId !== '' ? " AND Items.store_id = '$storeId'" : '';

    $sql = "SELECT
        Items.id,
        Items.idx,
        Items.`name`,
        Items.price,
        Items.media,
        Items.store_id AS storeid,
        Users.Fullname,
        Users.id AS user_id
    FROM
        Items
    LEFT JOIN Users
        ON Items.uid = Users.uid
    WHERE Items.Visibility = 'Public'
        AND Items.status = 1
        AND Items.`name` LIKE '%$searchQuery%'
        $storeClause
    ORDER BY Items.`name` ASC
    LIMIT 20";

    $result = $conx->query($sql);
    
    if ($result && $result->num_rows > 0) {
        $items = array();
        
        while($row = $result->fetch_assoc()) {
            $storeid = !empty($row['storeid']) ? (string)$row['storeid'] : '4';
            $itemId = (string)$row['id'];
            $itemIdx = (string)($row['idx'] ?? '');
            $thumbnail = ($storeid === '4')
                ? albadaa_thumbnail_url($itemId, $itemIdx)
                : "https://globee.b-cdn.net/{$itemId}/1.png";
            
            $item = array(
                'id' => $row['id'],
                'idx' => $itemIdx,
                'store_id' => $storeid,
                'storeid' => $storeid,
                'name' => $row['name'],
                'price' => $row['price'],
                'thumbnail' => $thumbnail,
                'seller' => array(
                    'id' => $row['user_id'],
                    'name' => $row['Fullname']
                )
            );
            
            $items[] = $item;
        }
        
        echo json_encode(array(
            'success' => true,
            'data' => $items
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
        'error' => 'Search error: ' . $e->getMessage()
    ));
}

$conx->close();
?>
