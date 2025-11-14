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
        
            $sql = "SELECT
                Items.id,
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
            WHERE Items.Visibility = 'Public' AND Items.status = 1
            ORDER BY RAND()
            LIMIT $limit OFFSET $offset";
        
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
        // إضافة صنف جديد (Insert Item)
        // =====================================
        case 'fetch_items_one_account':
            $uid = $_POST['uid'];
            $sql = "SELECT id, `name`, price, Views, media FROM Items WHERE uid = '$uid'";
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
                    );
                    
                    $items[] = $item;
                }
            }
            
            $response = array(
                'success' => true,
                'data' => $items,
            );
            break;
        case 'insert':
            // التحقق من البيانات المطلوبة
            $itemId = isset($_POST['item_id']) ? $conn->real_escape_string($_POST['item_id']) : '';
            $uid = isset($_POST['uid']) ? $conn->real_escape_string($_POST['uid']) : '';
            $name = isset($_POST['name']) ? $conn->real_escape_string($_POST['name']) : '';
            $category = isset($_POST['category']) ? $conn->real_escape_string($_POST['category']) : '';
            $price = isset($_POST['price']) ? $conn->real_escape_string($_POST['price']) : '';
            $qtt = isset($_POST['qtt']) ? (int)$_POST['qtt'] : 0;
            $description = isset($_POST['description']) ? $conn->real_escape_string($_POST['description']) : '';
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
            
            $sql = "UPDATE Items SET uid = '$uid', name = '$name', description = '$description', category = '$category', price = '$price', qtt = '$qtt', Visibility = '$visibility', comments = '$comments', media = '$media' WHERE id = '$itemId'";

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

            $sql = "INSERT INTO Items (id, created_at, status) VALUES (null, '$date', '0')";

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
            $date = date('Y-m-d');
        
           
                if (empty($phone)) {
                    $response = array(
                        'success' => false,
                        'error' => 'رقم الهاتف مطلوب'
                    );
                    break;
                }
                

                $sql = "INSERT INTO Users(Fullname, PhoneNumber, uid, oid, Created_at, status, player_id) VALUES('$name', '$phone', '$uid', '$oid', '$date', '0', '$player_id')";
            
                $result = $conn->query($sql);
                
                $response = array(
                    'success' => true,
                    'sql' => $sql
                );
                
            
            
            break;
        case 'get_tokens':
                $sql = "SELECT player_id FROM employees";
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
            
            try {
                $sql = "SELECT 
                    Items.id,
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
                WHERE Items.Visibility = 'Public' AND Items.status = 1
                ORDER BY Items.created_at DESC 
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
                $checkSql = "SELECT id, qtt FROM Cart 
                             WHERE item_id = '$item_id' 
                             AND user_id = '$user_id'";
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
                    
                    // ✅ التأكد من أن رقم الطلب فريد
                    $checkOrderIdSql = "SELECT id FROM Cart WHERE order_id = '$order_id'";
                    $checkOrderIdResult = $conn->query($checkOrderIdSql);
                    while ($checkOrderIdResult && $checkOrderIdResult->num_rows > 0) {
                        $order_id = isset($_POST['oid']) ? $conn->real_escape_string($_POST['oid']) : '';
                        $checkOrderIdResult = $conn->query($checkOrderIdSql);
                    }
                    
                    $insertSql = "INSERT INTO Cart (user_id, item_id, qtt, order_id) 
                                  VALUES ('$user_id', '$item_id', $quantity, '$order_id')";
                    
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



// Return JSON response
echo json_encode($response, true);
?>