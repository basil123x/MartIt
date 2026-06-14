<?php
include 'xtras/config.php';

$result = $conx->query("SELECT id, idx, store_id FROM Items WHERE idx IS NOT NULL AND idx != '' AND has_image = 0");

$updated = 0;
$notFound = 0;

while ($row = $result->fetch_assoc()) {
    $store_id = $row['store_id'] ?: '1';
    $idx = $row['idx'];
    $id = $row['id'];

    $url = "https://martit.s3.ap-south-1.amazonaws.com/store_{$store_id}/{$idx}/1.png";

    $headers = @get_headers($url);

    if ($headers && strpos($headers[0], '200') !== false) {
        $conx->query("UPDATE Items SET has_image = 1 WHERE id = '$id'");
        $updated++;
        echo "✅ Found: store_{$store_id}/{$idx}/1.png (id: $id)<br>";
    } else {
        $notFound++;
        echo "❌ Not found: store_{$store_id}/{$idx}/1.png (id: $id)<br>";
    }

    // Small delay to avoid hammering S3
    usleep(100000); // 0.1 second
}

echo "<br>Done! Updated: $updated | Not found: $notFound";
