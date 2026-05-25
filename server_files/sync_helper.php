<?php
require_once __DIR__ . '/clients_config.php';

// =============================================
// ONE function to sync item data to ANY client
// Replaces: syncToClientServer() and syncToGES()
// Usage: syncToClient($data, '2') or syncToClient($data, '3')
// =============================================
function syncToClient($data, $store_id) {
    global $clients;
    if (!isset($clients[$store_id])) return null;

    $client = $clients[$store_id];
    $mapped = [];

    foreach ($client['mapping'] as $myField => $clientField) {
        if ($clientField !== null && isset($data[$myField])) {
            $mapped[$clientField] = $data[$myField];
        }
    }

    if (isset($data['id']) && $data['id'] > 0) {
        $mapped['id'] = (int)$data['id'];
    }

    $ch = curl_init($client['sync_url']);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($mapped));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'X-Sync-Key: ' . $client['secret_key']
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $result = curl_exec($ch);
    curl_close($ch);
    return $result;
}

// =============================================
// ONE function to insert empty placeholder row on ANY client
// Replaces: syncEmptyItemToClient() and syncEmptyItemToGES()
// Usage: syncEmptyToClient('2') or syncEmptyToClient('3')
// =============================================
function syncEmptyToClient($store_id) {
    global $clients;
    if (!isset($clients[$store_id])) return 0;

    $client = $clients[$store_id];
    $postData = json_encode(['action' => 'insert_empty']);

    $ch = curl_init($client['sync_url']);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        'X-Sync-Key: ' . $client['secret_key']
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    $result = curl_exec($ch);
    curl_close($ch);

    $decoded = json_decode($result, true);
    return isset($decoded['id']) ? (int)$decoded['id'] : 0;
}
