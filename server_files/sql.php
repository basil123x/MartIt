<?php
// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set JSON header
header('Content-Type: application/json');

include 'xtras/config.php';

// Get action from POST request
$action = isset($_POST['action']) ? $_POST['action'] : '';

// Response array
$response = array('success' => false);

try {
    switch ($action) {
        
        // =====================================
        // جلب الأصناف (Fetch Items)
        // =====================================
        case 'fetch':
            $page = isset($_POST['page']) ? (int)$_POST['page'] : 0;
            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 10;
            $offset = $page * $limit;
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $itemSrchId = isset($_POST['itemSrchId']) ? $conn->real_escape_string($_POST['itemSrchId']) : '';
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '';
            $category = isset($_POST['category']) ? $conn->real_escape_string($_POST['category']) : '';
            $country = isset($_POST['country']) ? $conn->real_escape_string($_POST['country']) : '';
            $get_store = "";
            
            // Debug logging
            error_log("📦 fetch - Category received: " . ($category ? $category : 'NULL'));
            $img_url = "https://globee.b-cdn.net/";
            if ($store_id) {
                $get_store = "AND Items.store_id = '$store_id'";
            }
            switch ($store_id) {
                case '2':
                    $img_url = "https://globalfarmnursery.s3.ap-south-1.amazonaws.com/items/";
                    break;
                case '3':
                    $img_url = "https://globee.b-cdn.net/GES/";
                    break;
                default:
                    
                    break;
            }
            $d1 = "";
            $d2 = "";
            $d3 = "";
            if ($itemSrchId) {
                $d1 = "AND Items.id = '$itemSrchId'";
            }
            if (!empty($category)) {
                $d3 = "AND Items.category = '$category'";
            }
        
            $sql = "SELECT
                Items.id,
                Items.idx,
                Items.store_id AS storeid,
                Items.barcode,
                Items.`name`,
                Items.price,
                Items.qtt,
                Items.description,
                Items.Views,
                Items.media,
                Items.created_at,
                Users.Fullname,
                Users.uid AS user_id,
                Users.player_id AS token,
                COALESCE(likes_count.total_likes, 0) as likes_count,
                COALESCE(comments_count.total_comments, 0) as comments_count,
                COALESCE(cart_count.total_cart, 0) as cart_quantity,
                CASE WHEN user_likes.user_id IS NOT NULL THEN 1 ELSE 0 END as is_liked,
                CASE WHEN followers.buyer_id IS NOT NULL THEN 1 ELSE 0 END as is_following
            FROM
                Items
            LEFT JOIN Users
                ON Items.uid = Users.uid
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_likes 
                FROM Likes 
                GROUP BY item_id
            ) likes_count ON Items.id = likes_count.item_id
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_comments 
                FROM Comments 
                GROUP BY item_id
            ) comments_count ON Items.id = comments_count.item_id
            LEFT JOIN (
                SELECT item_id, SUM(qtt) as total_cart 
                FROM Cart " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "") . "
                GROUP BY item_id
            ) cart_count ON Items.id = cart_count.item_id
            LEFT JOIN (
                SELECT item_id, user_id 
                FROM Likes " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "WHERE 1=0") . "
            ) user_likes ON Items.id = user_likes.item_id
            LEFT JOIN (
                SELECT user_id, buyer_id
                FROM Followers " . (!empty($user_id) ? "WHERE buyer_id = '$user_id'" : "WHERE 1=0") . "
            ) followers ON Users.uid = followers.user_id
            WHERE Items.Visibility = 'Public' AND Items.status = 1 AND Items.country = '$country' $get_store $d1 $d3
            ORDER BY RAND()
            LIMIT $limit OFFSET $offset";

        
            // Debug: Log the SQL query
            error_log("📦 fetch SQL: " . $sql);
            
            $result = $conn->query($sql);
            $items = array();
            
            if ($result && $result->num_rows > 0) {
                while($row = $result->fetch_assoc()) {
                    $mediaFiles = array();
                    if (!empty($row['media'])) {
                        $mediaArray = explode(',', $row['media']);
                        foreach ($mediaArray as $media) {
                            $media = trim($media);
                            if (!empty($media)) {
                                // $mediaFiles[] = $img_url . $row['id'] . "/" . $media;
                                $mediaFiles[] = $img_url . $row['id'];
                            }
                        }
                    }
                    
                    $item = array(
                        'id' => (string)$row['id'],
                        'idx' => (string)$row['idx'],
                        'storeid' => (string)$row['storeid'],
                        'barcode' => (string)$row['barcode'],
                        'name' => (string)$row['name'],
                        'price' => (string)$row['price'],
                        'quantity' => (int)$row['qtt'],
                        'description' => (string)$row['description'],
                        'views' => (int)$row['Views'],
                        'media' => $mediaFiles,
                        'seller' => array(
                            'id' => (string)$row['user_id'],
                            'name' => (string)$row['Fullname'],
                            'avatar' => "https://globee.b-cdn.net/users/" . $row['user_id'] . "/avatar.jpg",
                            'isFollowing' => (bool)$row['is_following'],
                            'token' => $row['token']
                        ),
                        'interactions' => array(
                            'likes' => (int)$row['likes_count'],
                            'comments' => (int)$row['comments_count'],
                            'shares' => 0,
                            'cartQuantity' => (int)$row['cart_quantity'],
                            'isLiked' => (bool)$row['is_liked']
                        )
                    );
                    
                    $items[] = $item;
                }
            }
            
            $response = array(
                'success' => true,
                'data' => $items,
                'page' => $page,
                'hasMore' => count($items) >= $limit
            );
            break;
            
        case 'follow_user':
            $buyer_id = isset($_POST['buyer_id']) ? $conn->real_escape_string($_POST['buyer_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $user_token = isset($_POST['user_token']) ? $conn->real_escape_string($_POST['user_token']) : '';
        
            if (empty($buyer_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'بيانات غير كاملة'
                );
                break;
            }
        
            // ✅ شيك لو المستخدم بيتابع نفسه
            if ($buyer_id === $user_id) {
                $response = array(
                    'success' => false,
                    'error' => 'لا يمكنك متابعة نفسك'
                );
                break;
            }
        
            // ✅ شيك لو في متابعة موجودة
            $check_sql = "SELECT * FROM Followers WHERE buyer_id = '$buyer_id' AND user_id = '$user_id'";
            $check_result = $conn->query($check_sql);
        
            if ($check_result && $check_result->num_rows > 0) {
                // ✅ لو موجود، احذف المتابعة (unfollow)
                $delete_sql = "DELETE FROM Followers WHERE buyer_id = '$buyer_id' AND user_id = '$user_id'";
                
                if ($conn->query($delete_sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إلغاء المتابعة',
                        'action' => 'unfollowed'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إلغاء المتابعة: ' . $conn->error
                    );
                }
            } else {
                // ✅ لو مش موجود، أضف متابعة جديدة (follow)
                $insert_sql = "INSERT INTO Followers (buyer_id, user_id, user_token) 
                               VALUES ('$buyer_id', '$user_id', '$user_token')";
                
                if ($conn->query($insert_sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تمت المتابعة بنجاح',
                        'action' => 'followed'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في المتابعة: ' . $conn->error
                    );
                }
            }
            break;

        // =====================================
        // جلب منتجات حساب واحد (Fetch Items for One Account)
        // =====================================
        case 'fetch_items_one_account':
            $uid = $_POST['uid'];
            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 20;
            $offset = isset($_POST['offset']) ? (int)$_POST['offset'] : 0;
            $sort = isset($_POST['sort']) ? $_POST['sort'] : 'views';
            
            // Determine sort order
            $orderBy = "Views DESC"; // Default: الرائجة (most views)
            if ($sort === 'newest') {
                $orderBy = "id DESC";
            } else if ($sort === 'oldest') {
                $orderBy = "id ASC";
            }
            
            $sql = "SELECT id, `name`, price, Views, media, created_at FROM Items WHERE uid = '$uid' ORDER BY $orderBy LIMIT $limit OFFSET $offset";
            $result = $conn->query($sql);
            $items = array();
            
            if ($result && $result->num_rows > 0) {
                while($row = $result->fetch_assoc()) {
                    $mediaFiles = array();
                    if (!empty($row['media'])) {
                        $mediaArray = explode(',', $row['media']);
                        foreach ($mediaArray as $media) {
                            $media = trim($media);
                            if (!empty($media)) {
                                $mediaFiles[] = "https://globee.b-cdn.net/" . $row['id'] . "/" . $media;
                            }
                        }
                    }
                    
                    $item = array(
                        'id' => (string)$row['id'],
                        'name' => (string)$row['name'],
                        'price' => (string)$row['price'],
                        'views' => (int)$row['Views'],
                        'media' => $mediaFiles,
                        'created_at' => $row['created_at'] ?? '',
                    );
                    
                    $items[] = $item;
                }
            }
            
            // Get total count for pagination info
            $countSql = "SELECT COUNT(*) as total FROM Items WHERE uid = '$uid'";
            $countResult = $conn->query($countSql);
            $totalCount = 0;
            if ($countResult && $countRow = $countResult->fetch_assoc()) {
                $totalCount = (int)$countRow['total'];
            }
            
            $response = array(
                'success' => true,
                'data' => $items,
                'total' => $totalCount,
                'hasMore' => ($offset + $limit) < $totalCount,
            );
            break;
        case 'insert':
            // التحقق من البيانات المطلوبة
            $itemId = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $barcode = isset($_POST['barcode']) ? $conn->real_escape_string($_POST['barcode']) : '';
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $eng = isset($_POST['eng']) ? $conn->real_escape_string($_POST['eng']) : '';
            $category = isset($_POST['category']) ? $conn->real_escape_string($_POST['category']) : '';
            $price = isset($_POST['price']) ? $conn->real_escape_string($_POST['price']) : '';
            $qtt = isset($_POST['qtt']) ? (int)$_POST['qtt'] : 0;
            $description = isset($_POST['description']) ? $conn->real_escape_string($_POST['description']) : '';
            $description_arb = isset($_POST['description_arb']) ? $conn->real_escape_string($_POST['description_arb']) : '';
            $visibility = isset($_POST['visibility']) ? $conn->real_escape_string($_POST['visibility']) : 'Public';
            $media = isset($_POST['media']) ? $conn->real_escape_string($_POST['media']) : '';
            $comments = isset($_POST['comments']) ? $conn->real_escape_string($_POST['comments']) : '';

            if (empty($uid) || empty($name) || empty($price)) {
                $response = array(
                    'success' => false,
                    'error' => 'البيانات المطلوبة ناقصة (uid, name, price)'
                );
                break;
            }

            // $sql = "INSERT INTO Items (uid, `name`, price, qtt, description, Visibility, media, Views) 
            //         VALUES ('$uid', '$name', '$price', $qtt, '$description', '$visibility', '$media', 0)";
            
            $sql = "UPDATE Items SET uid = '$uid', barcode = '$barcode' ,name = '$name', eng = '$eng', description = '$description', description_arb = '$description_arb', category = '$category', price = '$price', qtt = '$qtt', Visibility = '$visibility', comments = '$comments', media = '$media' WHERE id = '$itemId'";

            if ($conn->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم إضافة الصنف بنجاح',
                    'item_id' => $conn->insert_id
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في إضافة الصنف: ' . $conn->error
                );
            }
            break;
            
        case 'insertNewOne':
            // التحقق من البيانات المطلوبة
            $date = date('Y-m-d H:i:s');
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '1';
            $country = isset($_POST['country']) ? $conn->real_escape_string($_POST['country']) : '1';

            $sql = "INSERT INTO Items (id, created_at, status, store_id, country) VALUES (null, '$date', '0', '$store_id', '$country')";

            if ($conn->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم إضافة الصنف بنجاح',
                    'item_id' => $conn->insert_id,
                    'sql_testing' => $sql
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في إضافة الصنف: ' . $conn->error
                );
            }
            break;
            
        case 'user_status':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $sql = "SELECT status FROM Users WHERE uid = '$uid' ";
            $status = $conn->query($sql)->fetch_array()[0];

            $response = array(
                'success' => true,
                'status' => $status
            );
            break;

        // =====================================
        // جلب التصنيفات (Get Categories)
        // =====================================
        case 'get_categories':
            $sql = "SELECT DISTINCT category 
                    FROM Items 
                    WHERE category IS NOT NULL 
                    AND category != '' 
                    ORDER BY category ASC";
            
            $result = $conn->query($sql);
            $categories = array();
            
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $categories[] = $row['category'];
                }
            }
            
            $response = array(
                'status' => 'success',
                'categories' => $categories
            );
            break;

        // =====================================
        // تحديث صنف (Update Item)
        // =====================================
        case 'update':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $updates = array();
            
            if (isset($_POST['name'])) {
                $name = $conn->real_escape_string($_POST['name']);
                $updates[] = "`name` = '$name'";
            }
            if (isset($_POST['price'])) {
                $price = $conn->real_escape_string($_POST['price']);
                $updates[] = "price = '$price'";
            }
            if (isset($_POST['quantity'])) {
                $qtt = (int)$_POST['quantity'];
                $updates[] = "qtt = $qtt";
            }
            if (isset($_POST['description'])) {
                $description = $conn->real_escape_string($_POST['description']);
                $updates[] = "description = '$description'";
            }
            if (isset($_POST['visibility'])) {
                $visibility = $conn->real_escape_string($_POST['visibility']);
                $updates[] = "Visibility = '$visibility'";
            }
            if (isset($_POST['media'])) {
                $media = $conn->real_escape_string($_POST['media']);
                $updates[] = "media = '$media'";
            }

            if (empty($updates)) {
                $response = array(
                    'success' => false,
                    'error' => 'لا توجد بيانات للتحديث'
                );
                break;
            }

            $sql = "UPDATE Items SET " . implode(', ', $updates) . " WHERE id = $item_id";

            if ($conn->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم تحديث الصنف بنجاح',
                    'affected_rows' => $conn->affected_rows
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في تحديث الصنف: ' . $conn->error
                );
            }
            break;

        // =====================================
        // حذف صنف (Delete Item)
        // =====================================
        case 'delete':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $sql = "DELETE FROM Items WHERE id = $item_id";

            if ($conn->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم حذف الصنف بنجاح',
                    'affected_rows' => $conn->affected_rows
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في حذف الصنف: ' . $conn->error
                );
            }
            break;

        // =====================================
        // جلب صنف واحد (Get Single Item)
        // =====================================
        case 'get_item':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $sql = "SELECT
                Items.*,
                Users.Fullname,
                Users.id AS user_id
            FROM
                Items
            LEFT JOIN Users
                ON Items.uid = Users.uid
            WHERE Items.id = $item_id";

            $result = $conn->query($sql);
            
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                
                $mediaFiles = array();
                if (!empty($row['media'])) {
                    $mediaArray = explode(',', $row['media']);
                    foreach ($mediaArray as $media) {
                        $media = trim($media);
                        if (!empty($media)) {
                            $mediaFiles[] = "https://globee.b-cdn.net/" . $row['id'] . "/" . $media;
                        }
                    }
                }
                
                $item = array(
                    'id' => (string)$row['id'],
                    'name' => (string)$row['name'],
                    'price' => (string)$row['price'],
                    'quantity' => (int)$row['qtt'],
                    'description' => (string)$row['description'],
                    'views' => (int)$row['Views'],
                    'visibility' => (string)$row['Visibility'],
                    'media' => $mediaFiles,
                    'seller' => array(
                        'id' => (string)$row['user_id'],
                        'name' => (string)$row['Fullname'],
                        'avatar' => "https://globee.b-cdn.net/users/" . $row['user_id'] . "/avatar.jpg"
                    )
                );
                
                $response = array(
                    'success' => true,
                    'data' => $item
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'الصنف غير موجود'
                );
            }
            break;

        // =====================================
        // زيادة عدد المشاهدات (Increment Views)
        // =====================================
        case 'increment_views':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $sql = "UPDATE Items SET Views = Views + 1 WHERE id = $item_id";

            if ($conn->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم تحديث المشاهدات'
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في تحديث المشاهدات: ' . $conn->error
                );
            }
            break;

        // =====================================
        // البحث عن أصناف (Search Items)
        // =====================================
        case 'search':
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
                                $thumbnail = "https://globee.b-cdn.net/" . $row['id'] . "/" . $firstMedia;
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
        
        case 'get_user_details':
            $phone = isset($_POST['phone']) ? trim($_POST['phone']) : '';
            if (isset($_POST['fcm_token']))
            {
                $id = isset($_POST['id']) ? trim($_POST['id']) : '';
                $oid = isset($_POST['oid']) ? trim($_POST['oid']) : '';
                $fcm_token = isset($_POST['fcm_token']) ? trim($_POST['fcm_token']) : '';
                $conn->query("UPDATE Users SET player_id = '$fcm_token', oid = '$oid' WHERE uid = '$id' ");
            }
        
            try {
                if (empty($phone)) {
                    $response = array(
                        'success' => false,
                        'error' => 'رقم الهاتف مطلوب'
                    );
                    break;
                }
                
                // استخدم prepared statement للأمان
                $phone = $conn->real_escape_string($phone);
                $sql = "SELECT Fullname, PhoneNumber, uid, urlAvatar, oid
                        FROM Users 
                        WHERE PhoneNumber = '$phone' 
                        LIMIT 1";
            
                $result = $conn->query($sql);
                
                // تحقق من وجود نتائج
                if ($result && $result->num_rows > 0) {
                    $row = $result->fetch_assoc(); // استخدم fetch_assoc بدلاً من fetch_array
                    
                    $user = array(
                        'id' => $row['uid'],
                        'oid' => $row['oid'],
                        'name' => $row['Fullname'],
                        'phone' => $row['PhoneNumber'],
                        'avatar' => $row['urlAvatar']
                    );
                    
                    $response = array(
                        'success' => true,
                        'data' => $user
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'المستخدم غير موجود'
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في البحث: ' . $e->getMessage()
                );
            }
            
            break;
            
        case 'create_account':
            $uid = isset($_POST['uid']) ? trim($_POST['uid']) : '';
            $oid = isset($_POST['oid']) ? trim($_POST['oid']) : '';
            $name = isset($_POST['name']) ? trim($_POST['name']) : '';
            $phone = isset($_POST['phone']) ? trim($_POST['phone']) : '';
            $player_id = isset($_POST['player_id']) ? trim($_POST['player_id']) : '';
            $store_id = isset($_POST['store_id']) ? trim($_POST['store_id']) : '1';
            $login_type = isset($_POST['login_type']) ? trim($_POST['login_type']) : '';
            $date = date('Y-m-d');
        
            if (empty($phone)) {
                $response = array(
                    'success' => false,
                    'error' => 'رقم الهاتف مطلوب'
                );
                break;
            }
            
            $userExists = $conn->query("SELECT PhoneNumber, uid FROM Users WHERE PhoneNumber = '$phone'");
            
            if (mysqli_num_rows($userExists) > 0) {
                // المستخدم موجود - لا تضيف
                $response = array(
                    'success' => false,
                    'error' => 'المستخدم موجود بالفعل'
                );
            } else {
                // المستخدم غير موجود - أضف
                $sql = "INSERT INTO Users(Fullname, PhoneNumber, uid, oid, Created_at, status, player_id, login_type, store_id) VALUES('$name', '$phone', '$uid', '$oid', '$date', '0', '$player_id', '$login_type', '$store_id')";
                $conn->query("UPDATE employees SET player_id = '$player_id' WHERE phone = '$phone'");
                $result = $conn->query($sql);
                
                $response = array(
                    'success' => true,
                    'message' => 'تم إضافة المستخدم بنجاح'
                );
            }
            break;
        case 'get_tokens':
                $empnumbers = '71402613';
                $sql = "SELECT id, phone, player_id FROM employees WHERE phone IN ($empnumbers)";
                $result = $conn->query($sql);
                $player_ids = array();
                while($rows = $result->fetch_assoc()) {
                    $player_ids[] = $rows;
                }
                
                
                
                $response = array(
                    'success' => true,
                    'player_ids' => $player_ids
                );
            break;

        // =====================================
        // جلب إحصائيات الصنف (Get Item Stats)
        // =====================================
        case 'get_stats':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            try {
                // جلب بيانات الصنف مع الإحصائيات
                $sql = "SELECT 
                    Items.description,
                    Items.Views,
                    Items.created_at,
                    COALESCE(COUNT(Likes.id), 0) AS likes_count
                FROM Items 
                LEFT JOIN Likes ON Likes.item_id = Items.id 
                WHERE Items.id = $item_id
                GROUP BY Items.id";

                $result = $conn->query($sql);
                
                if ($result && $result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    
                    // تنسيق التاريخ
                    $created_date = '';
                    if (!empty($row['created_at'])) {
                        $date = new DateTime($row['created_at']);
                        $created_date = $date->format('Y-m-d H:i');
                    }
                    
                    $stats = array(
                        'description' => (string)$row['description'],
                        'likes' => (int)$row['likes_count'],
                        'views' => (int)$row['Views'],
                        'created_at' => $created_date
                    );
                    
                    $response = array(
                        'success' => true,
                        'data' => $stats
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'الصنف غير موجود'
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الإحصائيات: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إضافة بلاغ (Add Report)
        // =====================================
        case 'add_report':
            $item_id = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $reason = isset($_POST['reason']) ? $conn->real_escape_string($_POST['reason']) : '';
            $created_at = date('Y-m-d H:i:s');
            
            if (empty($item_id) || empty($user_id) || empty($reason)) {
                $response = array(
                    'success' => false,
                    'error' => 'جميع البيانات مطلوبة (item_id, user_id, reason)'
                );
                break;
            }

            try {
                $sql = "INSERT INTO Flags (item_id, user_id, reason, created_at, status) 
                        VALUES ('$item_id', '$user_id', '$reason', '$created_at', 'pending')";

                if ($conn->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إرسال البلاغ بنجاح'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إرسال البلاغ: ' . $conn->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إرسال البلاغ: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب الأصناف مع حالة الإعجابات (Fetch with Likes)
        // =====================================
        case 'fetch_with_likes':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 10;
            $offset = isset($_POST['offset']) ? (int)$_POST['offset'] : 0;
            $itemSrchId = isset($_POST['itemSrchId']) ? $conn->real_escape_string($_POST['itemSrchId']) : '';
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '';
            $category = isset($_POST['category']) ? $conn->real_escape_string($_POST['category']) : '';
            $country = isset($_POST['country']) ? $conn->real_escape_string($_POST['country']) : '';
            $get_store = "";
            if ($store_id) {
                $get_store = "AND Items.store_id = '$store_id'";
            }
            // Debug logging
            error_log("📦 fetch_with_likes - Category received: " . ($category ? $category : 'NULL'));
            $img_url = "https://globee.b-cdn.net/";
            $d1 = "";
            $d2 = "";
            $d3 = "";
            if ($itemSrchId) {
                $d1 = "AND Items.id = '$itemSrchId'";
            }
            if (!empty($category)) {
                $d3 = "AND Items.category = '$category'";
            }
            
            try {
                $sql = "SELECT 
                    Items.id,
                    Items.idx,
                    Items.store_id AS storeid,
                    Items.barcode,
                    Items.name,
                    Items.price,
                    Items.qtt,
                    Items.description,
                    Items.Views,
                    Items.media,
                    Items.created_at,
                    Users.Fullname,
                    Users.uid AS user_id,
                    Users.player_id AS token,
                    COALESCE(likes_count.total_likes, 0) as likes_count,
                    CASE WHEN user_likes.user_id IS NOT NULL THEN 1 ELSE 0 END as is_liked,
                    CASE WHEN user_follows.buyer_id IS NOT NULL THEN 1 ELSE 0 END as is_following,
                    COALESCE(comments_count.total_comments, 0) as comments_count,
                    COALESCE(cart_count.total_cart, 0) as cart_quantity
                FROM Items 
                LEFT JOIN Users ON Items.uid = Users.uid
                LEFT JOIN (
                    SELECT item_id, COUNT(*) as total_likes 
                    FROM Likes 
                    GROUP BY item_id
                ) likes_count ON Items.id = likes_count.item_id
                LEFT JOIN (
                    SELECT item_id, user_id 
                    FROM Likes 
                    WHERE user_id = '$user_id'
                ) user_likes ON Items.id = user_likes.item_id
                LEFT JOIN (
                    SELECT user_id, buyer_id 
                    FROM Followers 
                    WHERE buyer_id = '$user_id'
                ) user_follows ON Items.uid = user_follows.user_id
                LEFT JOIN (
                    SELECT item_id, COUNT(*) as total_comments 
                    FROM Comments 
                    GROUP BY item_id
                ) comments_count ON Items.id = comments_count.item_id
                LEFT JOIN (
                    SELECT item_id, SUM(qtt) as total_cart 
                    FROM Cart 
                    WHERE user_id = '$user_id'
                    GROUP BY item_id
                ) cart_count ON Items.id = cart_count.item_id
                WHERE Items.Visibility = 'Public' AND Items.status = 1 AND Items.country = '$country' $get_store $d1 $d3
                ORDER BY RAND()
                LIMIT $limit OFFSET $offset";
        
                $result = $conn->query($sql);
                
                if ($result) {
                    $items = array();
                    while ($row = $result->fetch_assoc()) {
                        // ✅ معالجة الميديا
                        $mediaFiles = array();
                        if (!empty($row['media'])) {
                            $mediaArray = explode(',', $row['media']);
                            foreach ($mediaArray as $media) {
                                $media = trim($media);
                                if (!empty($media)) {
                                    $mediaFiles[] = $img_url . $row['id'] . "/" . $media;
                                }
                            }
                        }
                        
                        $item = array(
                            'id' => (string)$row['id'],
                            'idx' => (string)$row['idx'],
                            'storeid' => (string)$row['storeid'],
                            'barcode' => (string)$row['barcode'],
                            'name' => (string)$row['name'],
                            'price' => (string)$row['price'],
                            'quantity' => (int)$row['qtt'],
                            'description' => (string)$row['description'],
                            'views' => (int)$row['Views'],
                            'media' => $mediaFiles,
                            'seller' => array(
                                'id' => (string)$row['user_id'],
                                'name' => (string)$row['Fullname'],
                                'avatar' => "https://globee.b-cdn.net/users/" . $row['user_id'] . "/avatar.jpg",
                                'isFollowing' => (bool)$row['is_following'],
                                'token' => (string)($row['token'] ?? '')
                            ),
                            'interactions' => array(
                                'likes' => (int)$row['likes_count'],
                                'isLiked' => (bool)$row['is_liked'],
                                'comments' => (int)$row['comments_count'],
                                'shares' => 0,
                                'cartQuantity' => (int)$row['cart_quantity']
                            )
                        );
                        
                        $items[] = $item;
                    }
                    
                    $response = array(
                        'success' => true,
                        'data' => $items
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في جلب الأصناف: ' . $conn->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الأصناف: ' . $e->getMessage()
                );
            }
            break;
        case 'get_token_followers':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            try {
                $sql = "SELECT user_token FROM Followers WHERE user_id = '$user_id'";
                $result = $conn->query($sql);
                $tokens = array();
                while ($row = $result->fetch_assoc()) {
                    $tokens[] = $row;
                }
                
                $response = array(
                    'success' => true,
                    'data' => $tokens
                );
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الأصناف: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إدارة الإعجابات (Like/Unlike)
        // =====================================
        case 'toggle_like':
            $item_id = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }

            try {
                // التحقق من وجود إعجاب سابق
                $checkSql = "SELECT id FROM Likes WHERE item_id = '$item_id' AND user_id = '$user_id'";
                $checkResult = $conn->query($checkSql);
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    // إزالة الإعجاب
                    $deleteSql = "DELETE FROM Likes WHERE item_id = '$item_id' AND user_id = '$user_id'";
                    if ($conn->query($deleteSql)) {
                        $response = array(
                            'success' => true,
                            'action' => 'unliked',
                            'message' => 'تم إلغاء الإعجاب'
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في إلغاء الإعجاب: ' . $conn->error
                        );
                    }
                } else {
                    // إضافة إعجاب جديد
                    $created_at = date('Y-m-d H:i:s');
                    $insertSql = "INSERT INTO Likes (item_id, user_id, created_at) VALUES ('$item_id', '$user_id', '$created_at')";
                    if ($conn->query($insertSql)) {
                        $response = array(
                            'success' => true,
                            'action' => 'liked',
                            'message' => 'تم الإعجاب بنجاح'
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في إضافة الإعجاب: ' . $conn->error
                        );
                    }
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة الإعجاب: ' . $e->getMessage()
                );
            }
            break;
        // =====================================
        // إدارة سلة التسوق (Cart Management)
        // =====================================
        case 'add_to_cart':
            $item_id = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $quantity = isset($_POST['quantity']) ? (int)$_POST['quantity'] : 1;
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                // ✅ التحقق من وجود الصنف في السلة
                $checkSql = "SELECT id, qtt FROM Cart WHERE item_id = '$item_id' AND user_id = '$user_id'";
                $checkResult = $conn->query($checkSql);
                
                
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    // ✅ تحديث الكمية إذا كان الصنف موجود
                    $row = $checkResult->fetch_assoc();
                    $newQuantity = $row['qtt'] + $quantity;
                    $updateSql = "UPDATE Cart SET qtt = $newQuantity WHERE id = " . $row['id'];
                    
                    if ($conn->query($updateSql)) {
                        $response = array(
                            'success' => true,
                            'message' => 'تم تحديث الكمية في السلة',
                            'quantity' => $newQuantity
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في تحديث السلة: ' . $conn->error
                        );
                    }
                } else {
                     // ✅ إضافة صنف جديد للسلة
                        // ✅ رقم طلب عشوائي مكون من 8 أرقام
                        $order_id = isset($_POST['oid']) ? $conn->real_escape_string($_POST['oid']) : '';
                        
                        $insertSql = "INSERT INTO Cart (user_id, item_id, qtt, order_id) VALUES ('$user_id', '$item_id', $quantity, '$order_id')";
                        
                        if ($conn->query($insertSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم إضافة الصنف للسلة',
                                'quantity' => $quantity,
                                'order_id' => $order_id
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في إضافة الصنف للسلة: ' . $conn->error,
                                'sql' => $insertSql
                            );
                        }
                        
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة السلة: ' . $e->getMessage()
                );
            }
            break;
        
        case 'remove_from_cart':
            $item_id = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                // ✅ التحقق من وجود الصنف في السلة
                $checkSql = "SELECT id, qtt FROM Cart 
                             WHERE item_id = '$item_id' 
                             AND user_id = '$user_id'";
                $checkResult = $conn->query($checkSql);
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    $row = $checkResult->fetch_assoc();
                    $currentQuantity = $row['qtt'];
                    
                    if ($currentQuantity > 1) {
                        // ✅ تقليل الكمية
                        $newQuantity = $currentQuantity - 1;
                        $updateSql = "UPDATE Cart SET qtt = $newQuantity WHERE id = " . $row['id'];
                        
                        if ($conn->query($updateSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم تقليل الكمية',
                                'quantity' => $newQuantity
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في تحديث السلة: ' . $conn->error
                            );
                        }
                    } else {
                        // ✅ حذف الصنف من السلة (الكمية = 1)
                        $deleteSql = "DELETE FROM Cart WHERE id = " . $row['id'];
                        
                        if ($conn->query($deleteSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم حذف الصنف من السلة',
                                'quantity' => 0
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في حذف الصنف: ' . $conn->error
                            );
                        }
                    }
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'الصنف غير موجود في السلة',
                        'quantity' => 0
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة السلة: ' . $e->getMessage()
                );
            }
            break;
        
        case 'get_cart_quantity':
            $item_id = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                $sql = "SELECT COALESCE(SUM(qtt), 0) as total_quantity 
                        FROM Cart 
                        WHERE item_id = '$item_id' 
                        AND user_id = '$user_id'";
                $result = $conn->query($sql);
                
                if ($result) {
                    $row = $result->fetch_assoc();
                    $response = array(
                        'success' => true,
                        'quantity' => (int)$row['total_quantity']
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في جلب كمية السلة: ' . $conn->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب كمية السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب عناصر السلة (Get Cart Items)
        // =====================================
        case 'get_from_cart':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '1';
            
            if (empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }
            $get_store = "";
            if ($store_id) {
                $get_store = "AND Items.store_id = '$store_id'";
            }

            try {
                $sql = "SELECT 
                    Cart.id as cart_id,
                    Cart.qtt as cart_quantity,
                    Cart.order_id,
                    Items.id as item_id,
                    Items.idx as item_idx,
                    Items.name as item_name,
                    Items.price as item_price,
                    Items.qtt as available_quantity,
                    Items.media,
                    Users.store_id,
                    Users.Fullname as seller_name,
                    Users.uid as seller_id
                FROM Cart 
                LEFT JOIN Items ON Cart.item_id = Items.id
                LEFT JOIN Users ON Items.uid = Users.uid
                WHERE Cart.user_id = '$user_id' $get_store
                ORDER BY Cart.id DESC";

                $result = $conn->query($sql);
                $cartItems = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        // معالجة الميديا لأخذ أول صورة
                        $thumbnail = '';
                        if (!empty($row['media'])) {
                            $mediaArray = explode(',', $row['media']);
                            $firstMedia = trim($mediaArray[0]);
                            if (!empty($firstMedia)) {
                                $thumbnail = "https://globee.b-cdn.net/" . $row['item_id'] . "/" . $firstMedia;
                            }
                        }
                        
                        $cartItem = array(
                            'cart_id' => (string)$row['cart_id'],
                            'order_id' => (string)$row['order_id'],
                            'cart_quantity' => (int)$row['cart_quantity'],
                            'item' => array(
                                'id' => (string)$row['item_id'],
                                'idx' => (string)$row['item_idx'],
                                'name' => (string)$row['item_name'],
                                'price' => (string)$row['item_price'],
                                'available_quantity' => (int)$row['available_quantity'],
                                'thumbnail' => $thumbnail,
                                'store_id' => $row['store_id']
                            ),
                            'seller' => array(
                                'id' => (string)$row['seller_id'],
                                'name' => (string)$row['seller_name']
                            )
                        );
                        
                        $cartItems[] = $cartItem;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $cartItems
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب عناصر السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // تحديث كمية عنصر في السلة (Update Cart Quantity)
        // =====================================
        case 'update_cart_quantity':
            $cart_id = isset($_POST['cart_id']) ? (int)$_POST['cart_id'] : 0;
            $quantity = isset($_POST['quantity']) ? (int)$_POST['quantity'] : 1;
            
            if ($cart_id <= 0 || $quantity < 0) {
                $response = array(
                    'success' => false,
                    'error' => 'بيانات غير صحيحة'
                );
                break;
            }

            try {
                if ($quantity == 0) {
                    // حذف العنصر من السلة
                    $sql = "DELETE FROM Cart WHERE id = $cart_id";
                } else {
                    // تحديث الكمية
                    $sql = "UPDATE Cart SET qtt = $quantity WHERE id = $cart_id";
                }

                if ($conn->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => $quantity == 0 ? 'تم حذف العنصر من السلة' : 'تم تحديث الكمية',
                        'quantity' => $quantity
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في تحديث السلة: ' . $conn->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في تحديث السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إضافة عنوان شحن جديد (Add Shipping Address)
        // =====================================
        case 'add_shipping_address':
            $fullname = isset($_POST['fullname']) ? $conn->real_escape_string($_POST['fullname']) : '';
            $mobile = isset($_POST['mobile']) ? $conn->real_escape_string($_POST['mobile']) : '';
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $country = isset($_POST['country']) ? $conn->real_escape_string($_POST['country']) : '';
            $city = isset($_POST['city']) ? $conn->real_escape_string($_POST['city']) : '';
            $zone_number = isset($_POST['zone_number']) ? $conn->real_escape_string($_POST['zone_number']) : '';
            $street_number = isset($_POST['street_number']) ? $conn->real_escape_string($_POST['street_number']) : '';
            $building_number = isset($_POST['building_number']) ? $conn->real_escape_string($_POST['building_number']) : '';
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $oid = isset($_POST['oid']) ? $conn->real_escape_string($_POST['oid']) : '';
            
            if (empty($fullname) || empty($mobile) || empty($uid)) {
                $response = array(
                    'success' => false,
                    'error' => 'الاسم الكامل ورقم الهاتف ومعرف المستخدم مطلوبة'
                );
                break;
            }

            try {
                $sql = "INSERT INTO Shipping_Orders (Fullname, MobileNumber, Email, Country, City, `Zone Number`, `Street Number`, `Building Number`, uid, oid) 
                        VALUES ('$fullname', '$mobile', '$email', '$country', '$city', '$zone_number', '$street_number', '$building_number', '$uid', '$oid')";

                if ($conn->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إضافة العنوان بنجاح',
                        'address_id' => $conn->insert_id
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إضافة العنوان: ' . $conn->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إضافة العنوان: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب عناوين الشحن (Get Shipping Addresses)
        // =====================================
        case 'get_shipping_addresses':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            
            if (empty($uid)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }

            try {
                $sql = "SELECT * FROM Shipping_Orders WHERE uid = '$uid' ORDER BY id DESC";
                $result = $conn->query($sql);
                $addresses = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        $address = array(
                            'id' => (int)$row['id'],
                            'fullname' => (string)$row['Fullname'],
                            'mobile' => (string)$row['MobileNumber'],
                            'email' => (string)$row['Email'],
                            'country' => (string)$row['Country'],
                            'city' => (string)$row['City'],
                            'zone_number' => (string)$row['Zone Number'],
                            'street_number' => (string)$row['Street Number'],
                            'building_number' => (string)$row['Building Number'],
                            'uid' => (string)$row['uid'],
                            'oid' => (string)$row['oid']
                        );
                        
                        $addresses[] = $address;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $addresses
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب العناوين: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب البائعين الذين اشترى منهم المستخدم (Get User's Sellers)
        // =====================================
        case 'get_user_sellers':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }

            try {
                $sql = "SELECT 
                    Users.uid AS seller_id,
                    Users.Fullname AS seller_name,
                    Users.player_id AS seller_token,
                    (
                        SELECT conversation_id 
                        FROM Chat_Messages 
                        WHERE  Chat_Messages.seller_id = '$user_id'
                        ORDER BY Chat_Messages.id DESC 
                        LIMIT 1
                    ) AS conversation_id
                FROM
                    Users
                INNER JOIN Items ON Items.uid = Users.uid
                INNER JOIN Cart ON Cart.item_id = Items.id AND Cart.user_id = '$user_id'
                WHERE
                    Users.uid IS NOT NULL
                GROUP BY 
                    Users.uid,
                    Users.Fullname,
                    Users.player_id
                ORDER BY
                    Users.Fullname ASC";

                $result = $conn->query($sql);
                $sellers = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        $seller = array(
                            'id' => (string)$row['seller_id'],
                            'name' => (string)$row['seller_name'],
                            'avatar' => "https://globee.b-cdn.net/users/" . $row['seller_id'] . "/avatar.jpg",
                            'token' => (string)($row['seller_token'] ?? ''),
                            'conv_id' => (string)($row['conversation_id'] ?? '')
                        );
                        
                        $sellers[] = $seller;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $sellers
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب البائعين: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // تحديث الملف الشخصي
        // =====================================
        case 'update_user_profile':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $phone = isset($_POST['phone']) ? $conn->real_escape_string($_POST['phone']) : '';
            
            if (empty($uid) || empty($name) || empty($phone)) {
                $response = ['success' => false, 'error' => 'جميع الحقول مطلوبة'];
                break;
            }
            
            $sql = "UPDATE Users SET Fullname = '$name', PhoneNumber = '$phone' WHERE uid = '$uid'";
            
            if ($conn->query($sql) === TRUE) {
                $response = ['success' => true, 'message' => 'تم تحديث الملف الشخصي بنجاح'];
            } else {
                $response = ['success' => false, 'error' => 'فشل في تحديث الملف الشخصي: ' . $conn->error];
            }
            break;

        // =====================================
        // تفريغ السلة وتحديث OID
        // =====================================
        case 'clear_cart_update_oid':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $new_oid = isset($_POST['new_oid']) ? $conn->real_escape_string($_POST['new_oid']) : '';
            
            if (empty($user_id) || empty($new_oid)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم والـ OID الجديد مطلوبان'];
                break;
            }
            
            // Start transaction
            $conn->begin_transaction();
            
            try {
                // Clear cart for user
                $clear_cart_sql = "DELETE FROM Cart WHERE user_id = '$user_id'";
                if (!$conn->query($clear_cart_sql)) {
                    throw new Exception('فشل في تفريغ السلة: ' . $conn->error);
                }
                
                // Update user OID
                $update_oid_sql = "UPDATE Users SET oid = '$new_oid' WHERE uid = '$user_id'";
                if (!$conn->query($update_oid_sql)) {
                    throw new Exception('فشل في تحديث OID: ' . $conn->error);
                }
                
                // Commit transaction
                $conn->commit();
                $response = ['success' => true, 'message' => 'تم تفريغ السلة وتحديث OID بنجاح'];
                
            } catch (Exception $e) {
                // Rollback transaction
                $conn->rollback();
                $response = ['success' => false, 'error' => $e->getMessage()];
            }
            break;

        // =====================================
        // جلب رسائل الدردشة
        // =====================================
        case 'get_chat_messages':
            $sender_id = isset($_POST['sender_id']) ? $conn->real_escape_string($_POST['sender_id']) : '';
            $receiver_id = isset($_POST['receiver_id']) ? $conn->real_escape_string($_POST['receiver_id']) : '';
            $conversation_id = isset($_POST['conversation_id']) ? $conn->real_escape_string($_POST['conversation_id']) : '';
            
            if (empty($sender_id) || empty($receiver_id)) {
                $response = ['success' => false, 'error' => 'معرف المرسل والمستقبل مطلوبان'];
                break;
            }
            
            // إذا كان هناك conversation_id، جلب رسائل هذه المحادثة فقط
            if (!empty($conversation_id)) {
                $sql = "SELECT * FROM Chat_Messages 
                        WHERE conversation_id = '$conversation_id'
                        ORDER BY timestamp ASC";
            } else {
                // للتوافق مع النظام القديم
                $sql = "SELECT * FROM Chat_Messages 
                        WHERE (sender_id = '$sender_id' AND receiver_id = '$receiver_id') 
                        OR (sender_id = '$receiver_id' AND receiver_id = '$sender_id')
                        ORDER BY timestamp ASC";
            }
            
            $result = $conn->query($sql);
            $messages = [];
            
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $messages[] = $row;
                }
            }
            
            $response = ['success' => true, 'data' => $messages];
            break;

        // =====================================
        // إرسال رسالة دردشة
        // =====================================
        case 'send_chat_message':
            $sender_id = isset($_POST['sender_id']) ? $conn->real_escape_string($_POST['sender_id']) : '';
            $receiver_id = isset($_POST['receiver_id']) ? $conn->real_escape_string($_POST['receiver_id']) : '';
            $message = isset($_POST['message']) ? $conn->real_escape_string($_POST['message']) : '';
            $conversation_id = isset($_POST['conversation_id']) ? $conn->real_escape_string($_POST['conversation_id']) : '';
            $message_type = isset($_POST['message_type']) ? $conn->real_escape_string($_POST['message_type']) : 'text';
            $location_lat = isset($_POST['location_lat']) ? $conn->real_escape_string($_POST['location_lat']) : null;
            $location_lng = isset($_POST['location_lng']) ? $conn->real_escape_string($_POST['location_lng']) : null;
            
            if (empty($sender_id) || empty($receiver_id) || empty($message)) {
                $response = ['success' => false, 'error' => 'جميع الحقول مطلوبة'];
                break;
            }
            
            // ✅ إذا لم يكن هناك conversation_id، نبحث عن محادثة موجودة أو ننشئ واحدة ثابتة
            if (empty($conversation_id)) {
                // البحث عن محادثة موجودة بين المستخدمين
                $check_sql = "SELECT conversation_id FROM Chat_Messages 
                              WHERE (sender_id = '$sender_id' AND receiver_id = '$receiver_id')
                              OR (sender_id = '$receiver_id' AND receiver_id = '$sender_id')
                              LIMIT 1";
                $check_result = $conn->query($check_sql);
                
                if ($check_result && $check_result->num_rows > 0) {
                    // استخدام conversation_id الموجود
                    $row = $check_result->fetch_assoc();
                    $conversation_id = $row['conversation_id'];
                } else {
                    // إنشاء conversation_id ثابت بناءً على المستخدمين (الأصغر أولاً)
                    $min_id = min($sender_id, $receiver_id);
                    $max_id = max($sender_id, $receiver_id);
                    $conversation_id = "conv_{$min_id}_{$max_id}";
                }
            }
            
            $sql = "INSERT INTO Chat_Messages (sender_id, receiver_id, seller_id, message, conversation_id, message_type, location_lat, location_lng, timestamp, is_read) 
                    VALUES ('$sender_id', '$receiver_id', '$receiver_id', '$message', '$conversation_id', '$message_type', " . 
                    ($location_lat ? "'$location_lat'" : "NULL") . ", " . 
                    ($location_lng ? "'$location_lng'" : "NULL") . ", NOW(), 0)";
            
            if ($conn->query($sql) === TRUE) {
                $message_id = $conn->insert_id;
                $response = ['success' => true, 'message_id' => $message_id, 'conversation_id' => $conversation_id];
            } else {
                $response = ['success' => false, 'error' => 'فشل في إرسال الرسالة: ' . $conn->error];
            }
            break;

        // =====================================
        // إرسال إشعار دردشة
        // =====================================
        case 'send_chat_notification':
            $receiver_id = isset($_POST['receiver_id']) ? $conn->real_escape_string($_POST['receiver_id']) : '';
            $sender_name = isset($_POST['sender_name']) ? $conn->real_escape_string($_POST['sender_name']) : '';
            $message = isset($_POST['message']) ? $conn->real_escape_string($_POST['message']) : '';
            
            if (empty($receiver_id)) {
                $response = ['success' => false, 'error' => 'معرف المستقبل مطلوب'];
                break;
            }
            
            // Get receiver's FCM token
            $sql = "SELECT fcm_token FROM Users WHERE uid = '$receiver_id'";
            $result = $conn->query($sql);
            
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $fcm_token = $row['fcm_token'];
                
                if (!empty($fcm_token)) {
                    // TODO: Send push notification using OneSignal or FCM
                    // For now, just return success
                    $response = ['success' => true, 'message' => 'تم إرسال الإشعار'];
                } else {
                    $response = ['success' => false, 'error' => 'لا يوجد رمز إشعارات للمستخدم'];
                }
            } else {
                $response = ['success' => false, 'error' => 'المستخدم غير موجود'];
            }
            break;

        // =====================================
        // جلب قائمة المحادثات
        // =====================================
        case 'get_chat_conversations':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '';
            
            if (empty($user_id)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم مطلوب'];
                break;
            }
            
            // ✅ جلب المحادثات مجمّعة حسب الطرف الآخر (participant) وليس conversation_id
            // هذا يضمن ظهور محادثة واحدة لكل شخص حتى لو كان conversation_id مختلف
            $sql = "SELECT 
                participant_id,
                participant_name,
                participant_avatar,
                participant_token,
                last_message,
                last_message_time,
                conversation_id,
                COALESCE(unread_count, 0) as unread_count
            FROM (
                SELECT 
                    CASE 
                        WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                        ELSE cm.sender_id 
                    END as participant_id,
                    u.Fullname as participant_name,
                    CONCAT('https://globee.b-cdn.net/users/', u.uid, '/avatar.jpg') as participant_avatar,
                    u.player_id as participant_token,
                    cm.message as last_message,
                    cm.timestamp as last_message_time,
                    cm.conversation_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY CASE 
                            WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                            ELSE cm.sender_id 
                        END 
                        ORDER BY cm.timestamp DESC
                    ) as rn
                FROM Chat_Messages cm
                JOIN Users u ON u.uid = CASE 
                    WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                    ELSE cm.sender_id 
                END
                WHERE cm.sender_id = '$user_id' OR cm.receiver_id = '$user_id'
            ) as ranked_messages
            LEFT JOIN (
                SELECT 
                    CASE 
                        WHEN sender_id = '$user_id' THEN receiver_id 
                        ELSE sender_id 
                    END as p_id,
                    COUNT(*) as unread_count
                FROM Chat_Messages
                WHERE receiver_id = '$user_id' AND is_read = 0
                GROUP BY p_id
            ) as unread_counts ON unread_counts.p_id = participant_id
            WHERE rn = 1
            ORDER BY last_message_time DESC";
            
            error_log("🔍 get_chat_conversations - user_id: $user_id");
            
            $result = $conn->query($sql);
            
            // ✅ إذا فشل الاستعلام (MySQL قديم لا يدعم ROW_NUMBER)، نستخدم استعلام بديل
            if (!$result) {
                error_log("❌ get_chat_conversations - ROW_NUMBER failed, using fallback query");
                
                // استعلام بديل بدون ROW_NUMBER
                $sql = "SELECT 
                    CASE 
                        WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                        ELSE cm.sender_id 
                    END as participant_id,
                    u.Fullname as participant_name,
                    CONCAT('https://globee.b-cdn.net/users/', u.uid, '/avatar.jpg') as participant_avatar,
                    u.player_id as participant_token,
                    cm.message as last_message,
                    cm.timestamp as last_message_time,
                    cm.conversation_id,
                    0 as unread_count
                FROM Chat_Messages cm
                JOIN Users u ON u.uid = CASE 
                    WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                    ELSE cm.sender_id 
                END
                WHERE (cm.sender_id = '$user_id' OR cm.receiver_id = '$user_id')
                AND cm.timestamp = (
                    SELECT MAX(cm2.timestamp) 
                    FROM Chat_Messages cm2 
                    WHERE (cm2.sender_id = cm.sender_id AND cm2.receiver_id = cm.receiver_id)
                    OR (cm2.sender_id = cm.receiver_id AND cm2.receiver_id = cm.sender_id)
                )
                GROUP BY participant_id
                ORDER BY last_message_time DESC";
                
                $result = $conn->query($sql);
            }
            
            $conversations = [];
            
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $conversations[] = $row;
                }
            }
            
            error_log("✅ get_chat_conversations - Found " . count($conversations) . " conversations");
            $response = ['success' => true, 'data' => $conversations];
            break;

        // =====================================
        // تحديث حالة الاتصال
        // =====================================
        case 'update_online_status':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($user_id)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم مطلوب'];
                break;
            }
            
            $sql = "UPDATE Users SET last_seen = NOW() WHERE uid = '$user_id'";
            
            if ($conn->query($sql) === TRUE) {
                $response = ['success' => true];
            } else {
                $response = ['success' => false, 'error' => 'فشل في تحديث الحالة'];
            }
            break;

      // =====================================
        // جلب حالة الاتصال
        // =====================================
        case 'get_user_status':
            $user_id = isset($_POST['user_id']) ? $conn->real_escape_string($_POST['user_id']) : '';
            
            if (empty($user_id)) {
                echo json_encode(['success' => false, 'error' => 'معرف المستخدم مطلوب']);
                break;
            }
            
            $sql = "SELECT last_seen, 
                    TIMESTAMPDIFF(SECOND, last_seen, NOW()) as seconds_ago 
                    FROM Users WHERE uid = '$user_id'";
            
            $result = $conn->query($sql);
            
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $seconds_ago = $row['seconds_ago'];
                $minutes_ago = floor($seconds_ago / 60);
                
                // ✅ المستخدم متصل لو آخر ظهور أقل من 45 ثانية
                $is_online = $seconds_ago < 45;
                
                echo json_encode([
                    'success' => true, 
                    'is_online' => $is_online,
                    'last_seen' => $row['last_seen'],
                    'seconds_ago' => $seconds_ago,
                    'minutes_ago' => $minutes_ago
                ]);
            } else {
                echo json_encode(['success' => false, 'error' => 'المستخدم غير موجود']);
            }
            break;
            
        // =====================================
        // إنشاء طلب جديد (Create Order)
        // =====================================
        case 'create_order':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $cust_id = isset($_POST['cust_id']) ? $conn->real_escape_string($_POST['cust_id']) : '';
            $oid = isset($_POST['oid']) ? $conn->real_escape_string($_POST['oid']) : '';
            $ship_id = isset($_POST['ship_id']) ? $conn->real_escape_string($_POST['ship_id']) : '';
            $items = isset($_POST['items']) ? $_POST['items'] : '';
            $total_amount = isset($_POST['total_amount']) ? $conn->real_escape_string($_POST['total_amount']) : '';
            
            if (empty($uid) || empty($cust_id) || empty($oid)) {
                $response = ['success' => false, 'error' => 'البيانات المطلوبة ناقصة'];
                break;
            }
            
            try {
                $created_at = date('Y-m-d H:i:s');
                $sql = "INSERT INTO Orders (uid, cust_id, oid, ship_id, created_at, status, items, total_amount) 
                        VALUES ('$uid', '$cust_id', '$oid', '$ship_id', '$created_at', 'pending', '$items', '$total_amount')";
                
                if ($conn->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم إنشاء الطلب بنجاح',
                        'order_id' => $conn->insert_id
                    ];
                } else {
                    $response = ['success' => false, 'error' => 'فشل في إنشاء الطلب: ' . $conn->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في إنشاء الطلب: ' . $e->getMessage()];
            }
            break;

        // =====================================
        // جلب طلباتي كمشتري (Get My Orders as Buyer)
        // =====================================
        case 'get_my_orders':
            $cust_id = isset($_POST['cust_id']) ? $conn->real_escape_string($_POST['cust_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '';
            $myorders = "";
            // ✅ فقط نضيف فلتر المتجر إذا كان محدداً وليس فارغاً
            if (!empty($store_id) && $store_id != '1') {
                $myorders = "AND Users.store_id = '$store_id'";
            }
            
            // Debug logging
            error_log("🔍 get_my_orders - cust_id received: " . ($cust_id ? $cust_id : 'EMPTY'));
            error_log("🔍 get_my_orders - store_id received: " . ($store_id ? $store_id : 'EMPTY'));
            
            if (empty($cust_id)) {
                $response = ['success' => false, 'error' => 'معرف العميل مطلوب'];
                break;
            }
            
            try {
                $sql = "SELECT 
                    Orders.*,
                    Users.uid,
                    Users.Fullname as seller_name,
                    Users.PhoneNumber as seller_phone
                FROM Orders 
                LEFT JOIN Users ON Orders.uid = Users.uid
                WHERE Orders.cust_id = '$cust_id' $myorders
                ORDER BY Orders.created_at DESC";
                
                // Debug: Log the SQL query
                error_log("🔍 get_my_orders SQL: " . $sql);
                
                $result = $conn->query($sql);
                $orders = [];
                
                // Debug: Log result count
                $rowCount = $result ? $result->num_rows : 0;
                error_log("🔍 get_my_orders - Found $rowCount orders for cust_id: $cust_id");
                
                if ($result && $result->num_rows > 0) {
                    while ($row = $result->fetch_assoc()) {
                        $orders[] = [
                            'id' => (int)$row['id'],
                            'uid' => (string)$row['uid'],
                            'oid' => (string)$row['oid'],
                            'ship_id' => (string)$row['ship_id'],
                            'seller_id' => (string)$row['uid'],
                            'seller_name' => (string)$row['seller_name'],
                            'seller_phone' => (string)$row['seller_phone'],
                            'created_at' => (string)$row['created_at'],
                            'status' => (string)$row['status'],
                            'items' => (string)$row['items'],
                            'total_amount' => (string)$row['total_amount']
                        ];
                    }
                }
                
                error_log("🔍 get_my_orders - Returning " . count($orders) . " orders");
                $response = ['success' => true, 'data' => $orders];
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في جلب الطلبات: ' . $e->getMessage()];
            }
            break;

        // =====================================
        // جلب طلبات العملاء كبائع (Get Customer Orders as Seller)
        // =====================================
        case 'get_customer_orders':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            
            if (empty($uid)) {
                $response = ['success' => false, 'error' => 'معرف البائع مطلوب'];
                break;
            }
            
            try {
                $sql = "SELECT 
                    Orders.*,
                    Users.Fullname as customer_name,
                    Users.PhoneNumber as customer_phone,
                    Shipping_Orders.Fullname as ship_fullname,
                    Shipping_Orders.MobileNumber as ship_mobile,
                    Shipping_Orders.Country as ship_country,
                    Shipping_Orders.City as ship_city
                FROM Orders 
                LEFT JOIN Users ON Orders.cust_id = Users.uid
                LEFT JOIN Shipping_Orders ON Orders.ship_id = Shipping_Orders.id
                WHERE Orders.uid = '$uid'
                ORDER BY Orders.created_at DESC";
                
                $result = $conn->query($sql);
                $orders = [];
                
                if ($result && $result->num_rows > 0) {
                    while ($row = $result->fetch_assoc()) {
                        $orders[] = [
                            'id' => (int)$row['id'],
                            'oid' => (string)$row['oid'],
                            'ship_id' => (string)$row['ship_id'],
                            'customer_id' => (string)$row['cust_id'],
                            'customer_name' => (string)$row['customer_name'],
                            'customer_phone' => (string)$row['customer_phone'],
                            'created_at' => (string)$row['created_at'],
                            'status' => (string)$row['status'],
                            'items' => (string)$row['items'],
                            'total_amount' => (string)$row['total_amount'],
                            'shipping_info' => [
                                'fullname' => (string)$row['ship_fullname'],
                                'mobile' => (string)$row['ship_mobile'],
                                'country' => (string)$row['ship_country'],
                                'city' => (string)$row['ship_city']
                            ]
                        ];
                    }
                }
                
                $response = ['success' => true, 'data' => $orders];
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في جلب طلبات العملاء: ' . $e->getMessage()];
            }
            break;
            
        
        // =====================================
        // تحديث حالة الطلب (Update Order Status)
        // =====================================
        case 'update_order_status':
            $order_id = isset($_POST['order_id']) ? $conn->real_escape_string($_POST['order_id']) : '';
            $status = isset($_POST['status']) ? $conn->real_escape_string($_POST['status']) : '';
            
            if (empty($order_id) || empty($status)) {
                $response = ['success' => false, 'error' => 'معرف الطلب والحالة مطلوبان'];
                break;
            }
            
            // التحقق من أن الحالة صحيحة
            $valid_statuses = ['Pending', 'Preparing', 'ReadyToShip', 'Shipping', 'Delivered'];
            if (!in_array($status, $valid_statuses)) {
                $response = ['success' => false, 'error' => 'حالة غير صحيحة'];
                break;
            }
            
            try {
                $sql = "UPDATE Orders SET status = '$status' WHERE oid = '$order_id'";
                $customer_id = "SELECT
                                    Users.Fullname,
                                    Users.player_id
                                    FROM
                                    Orders
                                    LEFT JOIN Users
                                    ON Orders.uid = Users.uid
                                    WHERE Orders.oid = '$order_id'";
                $custo = array();
                $cok = $conn->query($customer_id);
                while($rows=mysqli_fetch_array($cok))
                {
                    $custo[] = $rows;
                }
                
                if ($conn->query($sql)) {
                    if ($conn->affected_rows > 0) {
                        $response = [
                            'success' => true, 
                            'message' => 'تم تحديث حالة الطلب بنجاح',
                            'new_status' => $status,
                            'client_token' => $custo
                        ];
                    } else {
                        $response = ['success' => false, 'error' => 'الطلب غير موجود أو الحالة لم تتغير'];
                    }
                } else {
                    $response = ['success' => false, 'error' => 'فشل في تحديث الحالة: ' . $conn->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في تحديث حالة الطلب: ' . $e->getMessage()];
            }
            break;
            
        // =====================================
        // حذف الحساب نهائياً
        // =====================================
        case 'delete_account_permit':
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            
            try {
                $sql = "DELETE FROM Users WHERE uid = '$uid'";
 
                
                if ($conn->query($sql)) {
                    $response = [
                        'success' => true, 
                        'message' => 'تم حذف الحساب نهائياً بنجاح',
                    ];
                } else {
                    $response = ['success' => false, 'error' => 'فشل في تحديث الحالة: ' . $conn->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في تحديث حالة الطلب: ' . $e->getMessage()];
            }
            break;
            
       case 'get_group':
            $store_id = isset($_POST['store_id']) ? $conn->real_escape_string($_POST['store_id']) : '';
            $get_store = "";
            
            if ($store_id) {
                $get_store = "AND store_id = '$store_id'";
            }
            
            // Debug logging
            error_log("📦 get_group - Store ID received: " . ($store_id ? $store_id : 'NULL'));
            
            try {
                // بناء الاستعلام
                $sql = "SELECT DISTINCT category FROM Items WHERE Visibility = 'Public' $get_store AND status = 1 AND category IS NOT NULL AND category != '' AND category != 'null'";
                
                // إضافة شرط المتجر إذا كان محدداً
                if (!empty($store_id)) {
                    $sql .= " AND store_id = '$store_id'";
                }
                
                $sql .= " ORDER BY category ASC";
                
                // Debug: Log the SQL query
                error_log("📦 get_group SQL: " . $sql);
                
                $result = $conn->query($sql);
                
                if ($result) {
                    $categories = [];
                    while ($row = $result->fetch_assoc()) {
                        $categories[] = [
                            'category' => $row['category']
                        ];
                    }
                    
                    $response = [
                        'success' => true,
                        'data' => $categories,
                        'count' => count($categories),
                        'message' => 'تم جلب المجموعات بنجاح'
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في جلب المجموعات: ' . $conn->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في جلب المجموعات: ' . $e->getMessage()
                ];
            }
            break;
        
        // =====================================
        // تسجيل الدخول بالبريد الإلكتروني
        // =====================================
        case 'login_with_email':
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $password = isset($_POST['password']) ? $_POST['password'] : '';
            
            try {
                // ← شيل OR Password IS NOT NULL دي غلط
                $sql = "SELECT uid, oid, Fullname, Email, Password FROM Users WHERE Email = '$email'";
                $result = $conn->query($sql);
                
                if ($result && $result->num_rows > 0) {
                    $user = $result->fetch_assoc();
                    
                    // السيناريو 1: متسجل بجوجل (Password = NULL)
                    if (is_null($user['Password'])) {
                        $response = [
                            'success' => false,
                            'message' => 'هذا الحساب مسجل بجوجل، يرجى تسجيل الدخول عبر جوجل'
                        ];
                    }
                    // السيناريو 2: حساب عادي
                    elseif (password_verify($password, $user['Password'])) {
                        $response = [
                            'success' => true,
                            'message' => 'تم تسجيل الدخول بنجاح',
                            'data' => [
                                'id' => $user['uid'],
                                'oid' => $user['oid'],
                                'name' => $user['Fullname'],
                                'email' => $user['Email']
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'message' => 'كلمة المرور غير صحيحة'
                        ];
                    }
                    
                } else {
                    // السيناريو 3: مش موجود خالص
                    $response = [
                        'success' => false,
                        'message' => 'المستخدم غير موجود'
                    ];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => $e->getMessage()];
            }
            break;

        // =====================================
        // إنشاء حساب بالبريد الإلكتروني
        // =====================================
        case 'create_email_account':
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $password = isset($_POST['password']) ? $_POST['password'] : '';
            $player_id = isset($_POST['player_id']) ? $conn->real_escape_string($_POST['player_id']) : '';
            $avatar_url = isset($_POST['avatar_url']) ? $conn->real_escape_string($_POST['avatar_url']) : '';
            // $hashed_password = password_hash($password, PASSWORD_DEFAULT);
            
            try {
                $check_sql = "SELECT uid FROM Users WHERE Email = '$email'";
                $check_result = $conn->query($check_sql);
                
                if ($check_result && $check_result->num_rows > 0) {
                    $response = [
                        'success' => false,
                        'message' => 'البريد الإلكتروني مسجل مسبقاً'
                    ];
                } else {
                    $uid = rand(1000, 9000);
                    $oid = rand(1000, 9000);
                    
                    $sql = "INSERT INTO Users (uid, oid, Fullname, Email, Password, player_id, urlAvatar, Created_At) 
                            VALUES ('$uid', '$oid', '$name', '$email', '$password', '$player_id', '$avatar_url', NOW())";
                    
                    if ($conn->query($sql)) {
                        $response = [
                            'success' => true,
                            'message' => 'تم إنشاء الحساب بنجاح',
                            'data' => [
                                'id' => (string)$uid,
                                'oid' => (string)$oid,
                                'name' => $name,
                                'email' => $email
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'error' => 'فشل في إنشاء الحساب: ' . $conn->error
                        ];
                    }
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;
        case 'create_social_account':
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $uid = rand(1000, 9000);
            $oid = rand(1000, 9000);
            $avatar_url = isset($_POST['avatar_url']) ? $conn->real_escape_string($_POST['avatar_url']) : '';
            $player_id = isset($_POST['player_id']) ? $conn->real_escape_string($_POST['player_id']) : '';
            $login_type = isset($_POST['login_type']) ? $conn->real_escape_string($_POST['login_type']) : '';
            $date = date('Y-m-d');
            try {
                    $sql = "INSERT INTO Users (uid, oid, Fullname, Email, player_id, login_type, urlAvatar, Created_At) 
                            VALUES ('$uid', '$oid', '$name', '$email', '$player_id', '$login_type', '$avatar_url', '$date')";
                    
                    if ($conn->query($sql)) {
                        $response = [
                            'success' => true,
                            'message' => 'تم إنشاء الحساب بنجاح',
                            'data' => [
                                'id' => (string)$uid,
                                'oid' => (string)$oid,
                                'name' => $name,
                                'email' => $email
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'error' => 'فشل في إنشاء الحساب: ' . $conn->error
                        ];
                    }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;
        case 'get_social_account':
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $avatar_url = isset($_POST['avatar_url']) ? $conn->real_escape_string($_POST['avatar_url']) : '';
            try {
                    $sql = "SELECT uid, oid, Fullname, email, urlAvatar, player_id FROM Users WHERE Fullname = '$name' AND email = '$email' AND urlAvatar = '$avatar_url' ";
                    
                    $user_social = $conn->query($sql)->fetch_array();
                    $uid = $user_social[0];
                    $oid = $user_social[1];
                    $response = [
                        'success' => true,
                        'message' => 'تم إنشاء الحساب بنجاح',
                        'data' => [
                            'id' => $uid,
                            'oid' => $oid,
                            'name' => $name,
                            'email' => $email,
                            'urlAvatar' => $avatar_url
                        ]
                    ];
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;

        // =====================================
        // تحديث FCM Token
        // =====================================
        case 'update_fcm_token':
            $email = isset($_POST['email']) ? $conn->real_escape_string($_POST['email']) : '';
            $fcm_token = isset($_POST['fcm_token']) ? $conn->real_escape_string($_POST['fcm_token']) : '';
            
            try {
                $sql = "UPDATE Users SET player_id = '$fcm_token' WHERE Email = '$email'";
                
                if ($conn->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم تحديث التوكن بنجاح'
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في تحديث التوكن: ' . $conn->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في تحديث التوكن: ' . $e->getMessage()
                ];
            }
            break;
            
        // =====================================
        // تحديث FCM Token
        // =====================================
        case 'add_new_transactions':
            $oid = isset($_POST['oid']) ? $conn->real_escape_string($_POST['oid']) : '';
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $mobile = isset($_POST['mobile']) ? $conn->real_escape_string($_POST['mobile']) : '';
            $trans_id = isset($_POST['trans_id']) ? $conn->real_escape_string($_POST['trans_id']) : '';
            $status = isset($_POST['status']) ? $conn->real_escape_string($_POST['status']) : '';
            $amount = isset($_POST['amount']) ? $conn->real_escape_string($_POST['amount']) : '';
            $pay_mode = isset($_POST['pay_mode']) ? $conn->real_escape_string($_POST['pay_mode']) : '';
            
            try {
                $sql = "INSERT INTO Transactions VALUES(NULL, '$oid', '$name', '$mobile','$trans_id', '$status', '$amount', '$pay_mode')";
                
                if ($conn->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم إضافة معاملة دفع جديدة'
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في إضافة المعاملة الجديدة: ' . $conn->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إضافة المعاملة الجديدة: ' . $e->getMessage()
                ];
            }
            break;


        // =====================================
        // Action غير صحيح
        // =====================================
        default:
            $response = array(
                'success' => false,
                'error' => 'Action غير صحيح أو غير موجود',
                'available_actions' => array(
                    'fetch' => 'جلب الأصناف',
                    'insert' => 'إضافة صنف',
                    'update' => 'تحديث صنف',
                    'delete' => 'حذف صنف',
                    'get_item' => 'جلب صنف واحد',
                    'increment_views' => 'زيادة المشاهدات',
                    'search' => 'البحث عن أصناف'
                )
            );
            
            break;
    }
    
} catch (Exception $e) {
    $response = array(
        'success' => false,
        'error' => 'خطأ في قاعدة البيانات: ' . $e->getMessage()
    );
}


echo json_encode($response, true);
?>