<?php
// Albadaa VPS local database (items table with a8 thumbnail filename).
// Configure these credentials on the Albadaa server — not Globee.
$albadaa_db_host = 'localhost';
$albadaa_db_user = 'your_albadaa_username';
$albadaa_db_pass = 'your_albadaa_password';
$albadaa_db_name = 'your_albadaa_database';

$albadaa_conn = @new mysqli(
    $albadaa_db_host,
    $albadaa_db_user,
    $albadaa_db_pass,
    $albadaa_db_name
);

if ($albadaa_conn->connect_error) {
    $albadaa_conn = null;
} else {
    $albadaa_conn->set_charset('utf8');
}
