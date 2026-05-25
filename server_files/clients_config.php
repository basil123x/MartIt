<?php
$clients = [
    '2' => [
        'name'       => 'GlobalFarm',
        'sync_url'   => 'https://gfnursery.com/s2026/sync_receive.php',
        'secret_key' => 'GlobalFarm_Secret_2026',
        'mapping'    => [
            'barcode'         => 'a1',
            'name'            => 'a3',
            'eng'             => 'a4',
            'category'        => 'a5',
            'description_arb' => 'a7',
            'description'     => 'a8',
            'price'           => 'a10',
            'qtt'             => 'a30',
        ],
    ],
    '3' => [
        'name'       => 'GES',
        'sync_url'   => 'https://ges.qa/gesqatar/sys2026/sync_receive.php',
        'secret_key' => 'GES_Secret_2026',
        'mapping'    => [
            'barcode'         => 'a1',
            'eng'             => 'a3',
            'name'            => 'a4',
            'category'        => 'a5',
            'description_arb' => 'a21',
            'description'     => 'a19',
            'price'           => 'a16',
            'qtt'             => null,
        ],
    ],
];
