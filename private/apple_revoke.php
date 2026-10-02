<?php
/**
 * Apple token revocation. Include this file; it does nothing until called.
 * Config is loaded from outside the public web root.
 */

function martit_apple_config_path() {
    $env = getenv('MARTIT_APPLE_CONFIG');
    if (is_string($env) && $env !== '' && is_file($env)) {
        return $env;
    }
    if (!defined('MARTIT_PRIVATE_DIR')) {
        $privateDir = getenv('MARTIT_PRIVATE_DIR');
        define(
            'MARTIT_PRIVATE_DIR',
            (is_string($privateDir) && $privateDir !== '') ? $privateDir : '/home/mart-it.store/private'
        );
    }
    $config = rtrim(MARTIT_PRIVATE_DIR, '/') . '/apple_config.php';
    if (is_file($config)) {
        return $config;
    }
    return null;
}

function martit_apple_load_config() {
    static $loaded = false;
    if ($loaded) {
        return defined('APPLE_CLIENT_ID');
    }
    $path = martit_apple_config_path();
    if ($path === null) {
        return false;
    }
    require_once $path;
    $loaded = true;
    return defined('APPLE_TEAM_ID') && defined('APPLE_KEY_ID') && defined('APPLE_CLIENT_ID') && defined('APPLE_P8_PATH');
}

function martit_apple_b64url($raw) {
    return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
}

function martit_apple_der_to_raw($der, $partLength = 32) {
    $offset = 0;
    $length = strlen($der);
    if ($length < 8 || ord($der[$offset]) !== 0x30) {
        throw new RuntimeException('invalid ecdsa signature');
    }
    $offset++;
    $seqLen = ord($der[$offset++]);
    if ($seqLen & 0x80) {
        $bytes = $seqLen & 0x7f;
        $seqLen = 0;
        for ($i = 0; $i < $bytes; $i++) {
            $seqLen = ($seqLen << 8) | ord($der[$offset++]);
        }
    }
    if ($offset >= $length || ord($der[$offset++]) !== 0x02) {
        throw new RuntimeException('invalid ecdsa r');
    }
    $rLen = ord($der[$offset++]);
    $r = substr($der, $offset, $rLen);
    $offset += $rLen;
    if ($offset >= $length || ord($der[$offset++]) !== 0x02) {
        throw new RuntimeException('invalid ecdsa s');
    }
    $sLen = ord($der[$offset++]);
    $s = substr($der, $offset, $sLen);
    $r = str_pad(ltrim($r, "\x00"), $partLength, "\x00", STR_PAD_LEFT);
    $s = str_pad(ltrim($s, "\x00"), $partLength, "\x00", STR_PAD_LEFT);
    if (strlen($r) !== $partLength || strlen($s) !== $partLength) {
        throw new RuntimeException('unexpected ecdsa length');
    }
    return $r . $s;
}

function martit_apple_client_secret($now = null) {
    if (!martit_apple_load_config()) {
        throw new RuntimeException('apple config missing');
    }
    if (APPLE_TEAM_ID === '' || APPLE_KEY_ID === '' || APPLE_CLIENT_ID === '' || !is_file(APPLE_P8_PATH)) {
        throw new RuntimeException('apple config incomplete');
    }
    $now = $now === null ? time() : (int)$now;
    $header = array('alg' => 'ES256', 'kid' => APPLE_KEY_ID);
    $claims = array(
        'iss' => APPLE_TEAM_ID,
        'iat' => $now,
        'exp' => $now + (15 * 60),
        'aud' => 'https://appleid.apple.com',
        'sub' => APPLE_CLIENT_ID,
    );
    $signingInput = martit_apple_b64url(json_encode($header)) . '.' . martit_apple_b64url(json_encode($claims));
    $pem = file_get_contents(APPLE_P8_PATH);
    $key = openssl_pkey_get_private($pem);
    if ($key === false) {
        throw new RuntimeException('apple key unreadable');
    }
    $der = '';
    $signed = openssl_sign($signingInput, $der, $key, OPENSSL_ALGO_SHA256);
    if (!$signed) {
        throw new RuntimeException('apple jwt sign failed');
    }
    return array(
        'header' => $header,
        'claims' => $claims,
        'client_secret' => $signingInput . '.' . martit_apple_b64url(martit_apple_der_to_raw($der)),
    );
}

function martit_apple_log($message) {
    $config = martit_apple_config_path();
    $dir = $config !== null ? dirname($config) : __DIR__;
    $safe = preg_replace('/(client_secret|refresh_token|access_token|id_token|authorization_code|code)["\s:=]+[^,\s}"]+/i', '$1=[redacted]', (string)$message);
    @file_put_contents($dir . '/apple_revoke.log', date('c') . ' ' . $safe . "\n", FILE_APPEND | LOCK_EX);
}

function martit_apple_public_error($body) {
    $decoded = json_decode((string)$body, true);
    if (!is_array($decoded)) {
        return 'apple http error';
    }
    $error = isset($decoded['error']) ? (string)$decoded['error'] : 'apple http error';
    martit_apple_log('apple response error=' . $error);
    return $error;
}

function martit_apple_form_post($url, array $fields) {
    if (!function_exists('curl_init')) {
        return array('ok' => false, 'status' => 0, 'body' => '', 'error' => 'curl missing');
    }
    $ch = curl_init($url);
    curl_setopt_array($ch, array(
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => http_build_query($fields, '', '&'),
        CURLOPT_HTTPHEADER => array('Content-Type: application/x-www-form-urlencoded'),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 20,
    ));
    $body = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    if ($body === false) {
        martit_apple_log('network error ' . $curlError);
        return array('ok' => false, 'status' => 0, 'body' => '', 'error' => 'network');
    }
    return array('ok' => $status >= 200 && $status < 300, 'status' => $status, 'body' => $body, 'error' => '');
}

function martit_apple_revoke_authorization_code($authorizationCode) {
    $authorizationCode = trim((string)$authorizationCode);
    if ($authorizationCode === '') {
        return array('ok' => false, 'error' => 'missing_code', 'http_status' => 0);
    }
    try {
        $jwt = martit_apple_client_secret();
    } catch (Exception $e) {
        martit_apple_log('config error ' . $e->getMessage());
        return array('ok' => false, 'error' => 'config', 'http_status' => 0);
    }

    $tokenResponse = martit_apple_form_post('https://appleid.apple.com/auth/token', array(
        'client_id' => APPLE_CLIENT_ID,
        'client_secret' => $jwt['client_secret'],
        'code' => $authorizationCode,
        'grant_type' => 'authorization_code',
    ));
    if (!$tokenResponse['ok']) {
        $reason = $tokenResponse['error'] !== '' ? $tokenResponse['error'] : martit_apple_public_error($tokenResponse['body']);
        return array('ok' => false, 'error' => $reason, 'http_status' => (int)$tokenResponse['status']);
    }
    $tokenJson = json_decode($tokenResponse['body'], true);
    if (!is_array($tokenJson)) {
        martit_apple_log('token response was not json');
        return array('ok' => false, 'error' => 'invalid_token_response', 'http_status' => (int)$tokenResponse['status']);
    }
    $token = '';
    $hint = 'refresh_token';
    if (!empty($tokenJson['refresh_token'])) {
        $token = (string)$tokenJson['refresh_token'];
    } elseif (!empty($tokenJson['access_token'])) {
        $token = (string)$tokenJson['access_token'];
        $hint = 'access_token';
    }
    if ($token === '') {
        martit_apple_log('token response missing refresh and access token');
        return array('ok' => false, 'error' => 'missing_token', 'http_status' => (int)$tokenResponse['status']);
    }

    $revokeResponse = martit_apple_form_post('https://appleid.apple.com/auth/revoke', array(
        'client_id' => APPLE_CLIENT_ID,
        'client_secret' => $jwt['client_secret'],
        'token' => $token,
        'token_type_hint' => $hint,
    ));
    if (!$revokeResponse['ok']) {
        $reason = $revokeResponse['error'] !== '' ? $revokeResponse['error'] : martit_apple_public_error($revokeResponse['body']);
        return array('ok' => false, 'error' => $reason, 'http_status' => (int)$revokeResponse['status']);
    }
    martit_apple_log('revoke succeeded hint=' . $hint);
    return array('ok' => true, 'error' => '', 'http_status' => (int)$revokeResponse['status']);
}
