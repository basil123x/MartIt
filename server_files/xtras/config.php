<?


// Create connection
$conx = mysqli_connect("localhost", "cdagvlmy_Globee", "A122%133z.", "cdagvlmy_Globee");

// Check connection
if ($conx->connect_error) {
    die("Connection failed: " . $conx->connect_error);
}

// Set charset to utf8 for Arabic support
$conx->set_charset("utf8");

// Backward compatibility for endpoints still using $conn
$conn = $conx;

// CORS headers for Flutter app
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}
?>
