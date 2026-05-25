<?php
header("Content-Type: application/json");
// الاتصال بقاعدة البيانات
include 'xtras/config.php';

// جلب معلومات المتجر والمنصة
$sId = "";
$platform = "";

if (isset($_GET['store_id'])) {
    $sId = $_GET['store_id'];
} else {
    $sId = '1';
}

if (isset($_GET['platform'])) {
    $platform = strtolower($_GET['platform']); // ios أو android
} else {
    $platform = 'android'; // افتراضي
}

// جلب آخر إصدارين فقط
$sql = "SELECT * FROM AppUpdate WHERE store_id = '$sId' ORDER BY id DESC LIMIT 2";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $stores = array();
    while($row = mysqli_fetch_assoc($result)) {
        $stores[] = $row;
    }
    
    // اختيار الإصدار المناسب حسب المنصة
    if ($platform == 'ios') {
        echo json_encode($stores[0]);
    } else {
        // android - أول واحد (الصف الأول)
        echo json_encode($stores[1]);
    }
} else {
    echo json_encode(["error" => "No data found"]);
}

$conn->close();
?>