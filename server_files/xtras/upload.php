<?php
/**
 * GES media upload — gesqatar/sys2026/xtras/upload.php
 *
 * If production already has upload.php, merge these fixes only:
 * 1. preg_replace: '/\.(jpg|jpeg|gif|pdf|png|webp)$/i'
 * 2. itmx: $ext from $_FILES['upload']['name'][0]; $filePath = $dir . $id . '.' . $ext;
 * 3. dbx:  $ext from $_FILES['upload']['name'][0]; $filePath = $dir . '0.' . $ext;
 *
 * Query: id={clientId}&sub=itmy|itmx|dbx — field: upload[]
 */

header('Content-Type: text/html; charset=UTF-8');

$id = isset($_GET['id']) ? preg_replace('/[^0-9]/', '', (string) $_GET['id']) : '';
$sub = isset($_GET['sub']) ? preg_replace('/[^a-z0-9]/', '', (string) $_GET['sub']) : 'itmy';

if ($id === '') {
    echo '<br>Missing id';
    exit;
}

$sys2026 = dirname(__DIR__);
$gesRoot = dirname($sys2026);
$attx2026 = $sys2026 . '/attx/';
$attx2025 = $gesRoot . '/sys2025/attx/';
$ext2 = '.png';

switch ($sub) {
    case 'itmx':
        $dir = $attx2026 . 'itmx/';
        break;
    case 'dbx':
        $dir = $attx2025 . 'dbx/' . $id . '/';
        break;
    case 'itmy':
    default:
        $sub = 'itmy';
        $dir = $attx2025 . 'itmy/' . $id . '/';
        break;
}

if (!is_dir($dir)) {
    mkdir($dir, 0755, true);
}

$countBefore = 0;
$entries = @scandir($dir);
if ($entries !== false) {
    $countBefore = count(array_diff($entries, ['.', '..']));
}

if (!isset($_FILES['upload'])) {
    echo "<br>There were $countBefore files uploaded before";
    exit;
}

$names = $_FILES['upload']['name'];
$tmpNames = $_FILES['upload']['tmp_name'];
$errors = $_FILES['upload']['error'];

if (!is_array($names)) {
    $names = [$names];
    $tmpNames = [$tmpNames];
    $errors = [$errors];
}

for ($i = 0; $i < count($names); $i++) {
    if ($errors[$i] !== UPLOAD_ERR_OK) {
        continue;
    }

    $newFileName = $names[$i];
    $tmpName = $tmpNames[$i];
    if (!is_uploaded_file($tmpName)) {
        continue;
    }

    $shortname = preg_replace('/\.(jpg|jpeg|gif|pdf|png|webp)$/i', $ext2, $newFileName);

    if ($sub === 'itmx') {
        $ext = pathinfo($_FILES['upload']['name'][0], PATHINFO_EXTENSION);
        $filePath = $dir . $id . '.' . $ext;
    } elseif ($sub === 'dbx') {
        $ext = pathinfo($_FILES['upload']['name'][0], PATHINFO_EXTENSION);
        $filePath = $dir . '0.' . $ext;
    } else {
        $filePath = $dir . $shortname;
    }

    move_uploaded_file($tmpName, $filePath);
}

echo "<br>There were $countBefore files uploaded before";
