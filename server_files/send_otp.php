<?php
/**
 * Phone OTP delivery. The app calls this file. Raqmee is called only here.
 */

function martit_load_raqmee_env()
{
    $paths = array();
    $privateDir = getenv('MARTIT_PRIVATE_DIR');
    if (!is_string($privateDir) || $privateDir === '') {
        $privateDir = '/home/mart-it.store/private';
    }
    $paths[] = rtrim($privateDir, '/') . '/.env';
    $paths[] = dirname(__DIR__, 2) . '/private/.env';
    $paths[] = dirname(__DIR__) . '/private/.env';
    $paths[] = dirname(__DIR__) . '/.env';
    $paths[] = __DIR__ . '/.env';

    foreach ($paths as $path) {
        if (!is_readable($path)) {
            continue;
        }
        $lines = file($path, FILE_IGNORE_NEW_LINES);
        if ($lines === false) {
            continue;
        }
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '' || $line[0] === '#') {
                continue;
            }
            $eq = strpos($line, '=');
            if ($eq === false) {
                continue;
            }
            $key = trim(substr($line, 0, $eq));
            $value = trim(substr($line, $eq + 1));
            if ($value !== '' && ($value[0] === '"' || $value[0] === "'")) {
                $value = trim($value, "\"'");
            }
            $existing = getenv($key);
            if ($key !== '' && ($existing === false || $existing === '')) {
                putenv($key . '=' . $value);
                $_ENV[$key] = $value;
            }
        }
    }
}

function martit_raqmee_e164($phone)
{
    $trimmed = trim((string)$phone);
    $digits = preg_replace('/\D+/', '', $trimmed);
    if ($digits === null || $digits === '') {
        return '';
    }
    if (strlen($digits) === 8) {
        return '+974' . $digits;
    }
    return '+' . $digits;
}

function martit_raqmee_log_failure($status, $body, $code)
{
    $safe = str_replace((string)$code, '[redacted]', (string)$body);
    error_log('Raqmee OTP send failed status=' . $status . ' body=' . $safe);
}

/**
 * Queue a WhatsApp OTP through Raqmee.
 * 202 means accepted, not delivered.
 */
function send_otp_via_raqmee($phone, $code, $name = '')
{
    martit_load_raqmee_env();

    $firstName = trim((string)$name);
    $nameLength = function_exists('mb_strlen')
        ? mb_strlen($firstName, 'UTF-8')
        : strlen($firstName);
    if ($nameLength < 2) {
        $firstName = 'عميل';
    }

    $phoneE164 = martit_raqmee_e164($phone);
    $code = trim((string)$code);
    if ($phoneE164 === '' || $code === '') {
        martit_raqmee_log_failure(0, 'invalid phone or code', $code);
        return false;
    }

    $url = rtrim((string)getenv('RAQMEE_INBOUND_URL'), '/');
    $secret = (string)getenv('RAQMEE_SIGNING_SECRET');
    if ($url === '' || $secret === '') {
        martit_raqmee_log_failure(0, 'missing config', $code);
        return false;
    }
    $suffix = '/customers/send-message';
    if (substr($url, -strlen($suffix)) !== $suffix) {
        $url .= $suffix;
    }

    // Extra template fields stay in this array.
    $fields = array(
        'first_name' => $firstName,
        'phone' => $phoneE164,
        'variable_1' => $code,
        'button_1_url' => $code,
    );
    $rawBody = json_encode($fields, JSON_UNESCAPED_UNICODE);
    if ($rawBody === false) {
        martit_raqmee_log_failure(0, 'json_encode failed', $code);
        return false;
    }

    $timestamp = (string)time();
    $signature = 'sha256=' . hash_hmac('sha256', $timestamp . '.' . $rawBody, $secret);
    $idempotency = bin2hex(random_bytes(16));

    $ch = curl_init($url);
    curl_setopt_array($ch, array(
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $rawBody,
        CURLOPT_HTTPHEADER => array(
            'Content-Type: application/json',
            'X-Raqmee-Timestamp: ' . $timestamp,
            'X-Raqmee-Signature: ' . $signature,
            'Idempotency-Key: ' . $idempotency,
        ),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_CONNECTTIMEOUT => 5,
    ));
    $responseBody = curl_exec($ch);
    $curlError = curl_error($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($responseBody === false || $curlError !== '') {
        martit_raqmee_log_failure($status, $curlError !== '' ? $curlError : 'curl failed', $code);
        return false;
    }
    if ($status !== 202) {
        martit_raqmee_log_failure($status, $responseBody, $code);
        return false;
    }
    return true;
}

if (basename($_SERVER['SCRIPT_FILENAME'] ?? '') === 'send_otp.php') {
    header('Content-Type: application/json; charset=UTF-8');
    $phone = isset($_POST['phone']) ? trim((string)$_POST['phone']) : '';
    $code = isset($_POST['code']) ? trim((string)$_POST['code']) : '';
    $name = isset($_POST['name']) ? trim((string)$_POST['name']) : '';

    if ($phone === '' || $code === '') {
        echo json_encode(array('success' => false, 'error' => 'حدث خطأ'));
        exit;
    }

    $config = __DIR__ . '/moderation_config.php';
    if (is_readable($config)) {
        require_once $config;
    }
    if (defined('MARTIT_DEMO_LOGIN_ENABLED') && MARTIT_DEMO_LOGIN_ENABLED
        && function_exists('martit_demo_phone_matches')
        && martit_demo_phone_matches($phone)) {
        echo json_encode(array('success' => true));
        exit;
    }

    $sent = send_otp_via_raqmee($phone, $code, $name);
    if ($sent) {
        echo json_encode(array('success' => true));
        exit;
    }
    echo json_encode(array('success' => false, 'error' => 'حدث خطأ'));
    exit;
}
