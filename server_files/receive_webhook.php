<?include("xtras/config.php");
$input = file_get_contents('php://input');
$data = json_decode($input, true);

// $data هنا مصفوفة من العناصر
foreach ($data as $item) {
    $product_id = $item['itemid'];
    $quantity   = $item['qtt'];

    // مثال: ممكن تحدث قاعدة البيانات مباشرة
    echo "Product: $product_id, Quantity: $quantity\n";
    $conn->query("UPDATE Items SET qtt = '$quantity' WHERE idx = '$product_id' ");
}

echo json_encode(["status" => "success", "message" => "Data received!"]);
?>
