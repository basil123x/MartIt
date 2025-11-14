<?php
include 'xtras/config.php';

// Get search query parameter
$searchQuery = isset($_GET['q']) ? trim($_GET['q']) : '';

try {
    if (empty($searchQuery)) {
        echo json_encode(array(
            'success' => true,
            'data' => array()
        ));
        exit;
    }
    
    // SQL query to search items by name
    $searchQuery = $conn->real_escape_string($searchQuery);
    $sql = "SELECT
        Items.id,
        Items.`name`,
        Items.price,
        Items.media,
        Users.Fullname,
        Users.id AS user_id
    FROM
        Items
    LEFT JOIN Users
        ON Items.uid = Users.uid
    WHERE Items.Visibility = 'Public' 
        AND Items.`name` LIKE '%$searchQuery%'
    ORDER BY Items.`name` ASC
    LIMIT 20";

    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        $items = array();
        
        while($row = $result->fetch_assoc()) {
            // Get first media file for thumbnail
            $thumbnail = '';
            if (!empty($row['media'])) {
                $mediaArray = explode(',', $row['media']);
                $firstMedia = trim($mediaArray[0]);
                if (!empty($firstMedia)) {
                    $thumbnail = "https://globee.b-cdnx.net/" . $row['id'] . "/" . $firstMedia;
                }
            }
            
            // Build search result object
            $item = array(
                'id' => $row['id'],
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

$conn->close();
?>
