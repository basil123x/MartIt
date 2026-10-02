<?php
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/apple_revoke.php';

if (!martit_apple_load_config()) {
    fwrite(STDERR, "apple_config.php was not found next to this script or in MARTIT_APPLE_CONFIG\n");
    exit(1);
}

$now = time();
$header = array('alg' => 'ES256', 'kid' => APPLE_KEY_ID);
$claims = array(
    'iss' => APPLE_TEAM_ID,
    'iat' => $now,
    'exp' => $now + (15 * 60),
    'aud' => 'https://appleid.apple.com',
    'sub' => APPLE_CLIENT_ID,
);

echo json_encode(array(
    'header' => $header,
    'claims' => $claims,
    'p8_file_exists' => is_file(APPLE_P8_PATH),
    'team_id_set' => APPLE_TEAM_ID !== '',
    'key_id_set' => APPLE_KEY_ID !== '',
), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), "\n";
