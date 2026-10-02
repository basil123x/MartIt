<?php
/**
 * Server-only review and safety settings.
 * Change the demo phone and code here. Do not show them in the app.
 */
define('MARTIT_DEMO_LOGIN_ENABLED', true);
define('MARTIT_DEMO_PHONE', '00000000');
define('MARTIT_DEMO_CODE', '000000');
define('MARTIT_DEMO_UID', '9001');

define('MARTIT_CONTACT_EMAIL', 'support@mart-it.store');
define('SkDjwUc36vHy5tPC9Sf4VaHMC2VWSNFM', 'change-me-before-upload');

function martit_banned_words() {
    return array(
        'fuck', 'shit', 'bitch', 'porn', 'nude', 'nudes', 'xxx', 'scam', 'spam',
        'احتيال', 'نصب', 'اباحي', 'إباحي', 'اباحية', 'إباحية', 'قذر', 'سكس', 'عاهر',
    );
}

function martit_text_has_banned_word($text) {
    $haystack = mb_strtolower((string)$text, 'UTF-8');
    foreach (martit_banned_words() as $word) {
        $needle = mb_strtolower($word, 'UTF-8');
        if ($needle !== '' && mb_strpos($haystack, $needle, 0, 'UTF-8') !== false) {
            return true;
        }
    }
    return false;
}

function martit_digits($value) {
    return preg_replace('/\D+/', '', (string)$value);
}

function martit_demo_phone_matches($posted) {
    $posted = martit_digits($posted);
    $expected = martit_digits(MARTIT_DEMO_PHONE);
    if ($posted === '' || $expected === '') {
        return false;
    }
    if (hash_equals($expected, $posted)) {
        return true;
    }
    $extra = strlen($posted) - strlen($expected);
    if ($extra > 0 && $extra <= 4) {
        return hash_equals($expected, substr($posted, -strlen($expected)));
    }
    return false;
}
