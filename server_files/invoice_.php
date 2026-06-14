<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/html; charset=utf-8');

$conn = mysqli_connect("localhost", "cdagvlmy_Globee", "A122%133z.", "cdagvlmy_Globee");

$order_id = isset($_GET['order_id']) ? (int)$_GET['order_id'] : 0;
$user_id  = isset($_GET['user_id'])  ? (int)$_GET['user_id']  : 0;
$store_id = isset($_GET['store_id']) ? (string)$_GET['store_id'] : 0;

$email = "";
$site  = "";
$phone = "";
$name  = "";

switch ($store_id) {
    case '2':
        $name  = "Global Farm";
        $email = "info@gfnursery.net";
        $site  = "gfnursery.net";
        $phone = "+97477991225";
        break;
    case '3':
        $name  = "Golden Eagle Stores";
        $email = "info@ges.qa";
        $site  = "ges.qa";
        $phone = "44414156";
        break;
    default:
        $name  = "MartIt";
        $email = "info@martit.com";
        $site  = "MartIt.com";
        $phone = "71402613";
        break;
}

$d1 = $order_id
    ? "Orders.oid = '$order_id'"
    : "Orders.uid = '$user_id'";

$sql = "SELECT 
    Orders.*,
    seller.Fullname as seller_name,
    seller.PhoneNumber as seller_phone,
    customer.Fullname as customer_name,
    customer.PhoneNumber as customer_phone,
    Shipping_Orders.Fullname as ship_fullname,
    Shipping_Orders.MobileNumber as ship_mobile,
    Shipping_Orders.Email as ship_email,
    Shipping_Orders.Country as ship_country,
    Shipping_Orders.City as ship_city,
    Shipping_Orders.`Zone Number` as ship_zone,
    Shipping_Orders.`Street Number` as ship_street,
    Shipping_Orders.`Building Number` as ship_building
FROM Orders 
LEFT JOIN Users as seller ON Orders.uid = seller.uid
LEFT JOIN Users as customer ON Orders.cust_id = customer.uid
LEFT JOIN Shipping_Orders ON Orders.ship_id = Shipping_Orders.id
WHERE $d1";

$result = $conn->query($sql);

if (!$result || $result->num_rows == 0) {
    die('الطلب غير موجود');
}

$order = $result->fetch_assoc();

$resultx = $conn->query($sql);
$items = [];
while ($row = mysqli_fetch_array($resultx)) {
    $items[] = $row;
}

$total = 0;

$statusMap = [
    'pending'   => ['label' => 'قيد المعالجة', 'color' => '#B45309'],
    'completed' => ['label' => 'مكتمل',         'color' => '#15803D'],
    'cancelled' => ['label' => 'ملغي',           'color' => '#B91C1C'],
];
$statusInfo = $statusMap[$order['status']] ?? ['label' => $order['status'], 'color' => '#555'];

// Pre-calculate total
foreach ($items as $row) {
    $decoded  = json_decode($row['items'], true)[0] ?? [];
    $price    = (float)($decoded['price']    ?? 0);
    $qty      = (int)  ($decoded['quantity'] ?? 0);
    $total   += $price * $qty;
}
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>فاتورة #<?php echo $order['oid']; ?> — <?= htmlspecialchars($name); ?></title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Cairo', sans-serif;
            background: #e5e7eb;
            padding: 30px 16px 50px;
            direction: rtl;
        }

        .page {
            max-width: 780px;
            margin: 0 auto;
            background: #fff;
            box-shadow: 0 4px 24px rgba(0,0,0,0.13);
        }

        /* ── HEADER ── */
        .inv-header {
            position: relative;
            height: 160px;
            overflow: hidden;
            background: #C0392B;
        }

        .header-left {
            position: absolute;
            top: 0; right: 0;
            width: 58%;
            height: 100%;
            background: #1B2A4A;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 30px 36px;
            /* curved right edge using border-radius trick */
            border-radius: 0 0 0 60px / 0 0 0 100%;
        }

        .header-left h1 {
            color: #fff;
            font-size: 36px;
            font-weight: 900;
            line-height: 1.3;
            text-align: center;
        }

        .header-right {
            position: absolute;
            top: 0; left: 0;
            width: 46%;
            height: 100%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 20px;
        }

        .header-logo {
            width: 80px;
            height: 80px;
            object-fit: contain;
            filter: brightness(0) invert(1);
        }

        .header-brand {
            color: #fff;
            font-size: 22px;
            font-weight: 800;
        }

        /* ── META BAND ── */
        .meta-band {
            background: #f9f9f9;
            border-top: 3px solid #C0392B;
            border-bottom: 1px solid #e0e0e0;
            padding: 18px 36px;
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            gap: 20px;
        }

        .meta-customer { flex: 1; }

        .meta-label {
            color: #C0392B;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 4px;
        }

        .meta-customer-name {
            font-size: 22px;
            font-weight: 900;
            color: #111;
            margin-bottom: 10px;
        }

        .meta-customer-details {
            font-size: 13px;
            color: #444;
            line-height: 1.9;
        }

        .meta-right {
            text-align: left;
            flex-shrink: 0;
        }

        .meta-total-label {
            color: #C0392B;
            font-size: 13px;
            font-weight: 700;
        }

        .meta-total-amount {
            font-size: 32px;
            font-weight: 900;
            color: #111;
            margin-bottom: 12px;
        }

        .meta-inv-line {
            font-size: 13px;
            color: #555;
            line-height: 1.8;
        }

        .status-badge {
            display: inline-block;
            padding: 3px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 700;
            color: #fff;
            margin-top: 4px;
        }

        /* ── DIVIDER ── */
        .divider {
            height: 4px;
            background: linear-gradient(to left, #C0392B 0%, #C0392B 40%, #1B2A4A 40%, #1B2A4A 100%);
        }

        /* ── TABLE ── */
        .table-wrap { padding: 0 36px; }

        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin: 28px 0 0;
        }

        .items-table thead tr {
            background: #1B2A4A;
            color: #fff;
        }

        .items-table thead th:first-child {
            background: #C0392B;
            width: 160px;
        }

        .items-table th {
            padding: 13px 18px;
            font-size: 14px;
            font-weight: 700;
            text-align: center;
        }

        .items-table th:first-child { text-align: right; }

        .items-table td {
            padding: 13px 18px;
            font-size: 14px;
            text-align: center;
            border-bottom: 1px solid #e8e8e8;
            color: #222;
        }

        .items-table td:first-child { text-align: right; }

        .items-table tbody tr:nth-child(even) { background: #fafafa; }

        /* ── TOTALS ── */
        .totals-section {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            padding: 24px 36px 10px;
            gap: 24px;
        }

        .return-policy {
            flex: 1;
            font-size: 13px;
            color: #444;
            line-height: 1.8;
            padding-top: 6px;
        }

        .return-policy strong {
            color: #111;
            display: block;
            font-size: 14px;
            margin-bottom: 4px;
        }

        .totals-table {
            width: 220px;
            flex-shrink: 0;
        }

        .totals-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 6px 0;
            font-size: 14px;
            color: #333;
            border-bottom: 1px solid #eee;
        }

        .totals-row .t-label { font-weight: 700; }

        .totals-grand {
            background: #C0392B;
            margin-top: 10px;
            padding: 12px 16px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .totals-grand .t-label {
            color: #fff;
            font-size: 18px;
            font-weight: 900;
        }

        .totals-grand .t-amount {
            color: #fff;
            font-size: 18px;
            font-weight: 900;
        }

        /* ── FOOTER ── */
        .inv-footer {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            padding: 24px 36px 30px;
            border-top: 1px solid #e8e8e8;
            margin-top: 10px;
        }

        .footer-thank {
            color: #C0392B;
            font-size: 18px;
            font-weight: 800;
            font-style: italic;
        }

        .footer-contacts {
            font-size: 12px;
            color: #666;
            line-height: 1.9;
            text-align: left;
        }

        .sig-block {
            text-align: center;
        }

        .sig-label {
            font-size: 13px;
            color: #333;
            border-top: 1.5px solid #999;
            padding-top: 6px;
            margin-top: 28px;
            font-weight: 700;
        }

        /* bottom accent strip */
        .bottom-strip {
            height: 8px;
            background: linear-gradient(to left, #C0392B 50%, #1B2A4A 50%);
        }

        /* ── PRINT BUTTON ── */
        .print-btn {
            display: flex;
            align-items: center;
            gap: 10px;
            margin: 24px auto 0;
            padding: 13px 44px;
            background: #1B2A4A;
            color: #fff;
            border: none;
            font-family: 'Cairo', sans-serif;
            font-size: 15px;
            font-weight: 700;
            cursor: pointer;
            border-radius: 4px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.18);
            transition: background 0.2s;
        }

        .print-btn:hover { background: #C0392B; }

        .print-btn svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 2; }

        @media print {
            @page { size: A4 portrait; margin: 0; }
            * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
            body { padding: 0; background: white; }
            .print-btn { display: none !important; }
        }

        @media (max-width: 600px) {
            .header-left { clip-path: none; padding: 20px; }
            .header-left h1 { font-size: 24px; }
            .header-right { width: 130px; padding: 14px; }
            .header-brand { font-size: 15px; }
            .meta-band { flex-direction: column; }
            .meta-right { text-align: right; }
            .totals-section { flex-direction: column; }
            .totals-table { width: 100%; }
            .table-wrap { padding: 0 14px; }
            .inv-footer { flex-direction: column; gap: 16px; }
            .footer-contacts { text-align: right; }
        }
    </style>
</head>
<body>

<div class="page">

    <!-- HEADER -->
    <div class="inv-header">
        <div class="header-left">
            <h1>فاتورة<br>مبيعات</h1>
        </div>
        <div class="header-right">
            <img src="../sys/assets/img/<?= $store_id; ?>.png?k=<?= time(); ?>" alt="<?= htmlspecialchars($name); ?>" class="header-logo">
            <div class="header-brand"><?= htmlspecialchars($name); ?></div>
        </div>
    </div>

    <!-- META BAND -->
    <div class="meta-band">
        <div class="meta-customer">
            <?php if (!empty($order['ship_fullname'])): ?>
            <div class="meta-label">اسم المشتري :</div>
            <div class="meta-customer-name"><?= htmlspecialchars($order['ship_fullname']); ?></div>
            <div class="meta-customer-details">
                <?php if (!empty($order['ship_mobile'])): ?>
                    رقم التليفون : <span dir="ltr"><?= htmlspecialchars($order['ship_mobile']); ?></span><br>
                <?php endif; ?>
                <?php if (!empty($order['ship_email'])): ?>
                    البريد الالكتروني : <?= htmlspecialchars($order['ship_email']); ?><br>
                <?php endif; ?>
                <?php
                    $parts = [];
                    if (!empty($order['ship_city']))     $parts[] = $order['ship_city'];
                    if (!empty($order['ship_country']))  $parts[] = $order['ship_country'];
                    if (!empty($order['ship_zone']))     $parts[] = 'منطقة ' . $order['ship_zone'];
                    if (!empty($order['ship_street']))   $parts[] = 'شارع '  . $order['ship_street'];
                    if (!empty($order['ship_building'])) $parts[] = 'مبنى '  . $order['ship_building'];
                    if ($parts): ?>
                    العنوان : <?= htmlspecialchars(implode(', ', $parts)); ?>
                <?php endif; ?>
            </div>
            <?php elseif (!empty($order['customer_name'])): ?>
            <div class="meta-label">اسم المشتري :</div>
            <div class="meta-customer-name"><?= htmlspecialchars($order['customer_name']); ?></div>
            <div class="meta-customer-details">
                <?php if (!empty($order['customer_phone'])): ?>
                    رقم التليفون : <span dir="ltr"><?= htmlspecialchars($order['customer_phone']); ?></span>
                <?php endif; ?>
            </div>
            <?php endif; ?>
        </div>

        <div class="meta-right">
            <div class="meta-total-label">المبلغ الاجمالي</div>
            <div class="meta-total-amount"><?= number_format($total, 2); ?> ر.ق</div>
            <div class="meta-inv-line">
                رقم الفاتورة : #<?= $order['oid']; ?><br>
                تاريخ الفاتورة : <?= date('d / m / Y', strtotime($order['created_at'])); ?>
            </div>
            <div>
                <span class="status-badge" style="background: <?= htmlspecialchars($statusInfo['color']); ?>">
                    <?= htmlspecialchars($statusInfo['label']); ?>
                </span>
            </div>
        </div>
    </div>

    <div class="divider"></div>

    <!-- TABLE -->
    <div class="table-wrap">
        <table class="items-table">
            <thead>
                <tr>
                    <th>اسم المنتج</th>
                    <th>الكمية</th>
                    <th>السعر</th>
                    <th>الأجمالي</th>
                </tr>
            </thead>
            <tbody>
                <?php
                $total = 0;
                foreach ($items as $i => $row):
                    $decoded  = json_decode($row['items'], true)[0] ?? [];
                    $price    = (float)($decoded['price']    ?? 0);
                    $qty      = (int)  ($decoded['quantity'] ?? 0);
                    $subtotal = $price * $qty;
                    $total   += $subtotal;
                ?>
                <tr>
                    <td><?= htmlspecialchars($decoded['name'] ?? '—'); ?></td>
                    <td><?= $qty; ?></td>
                    <td><?= number_format($price, 2); ?> ر.ق</td>
                    <td><?= number_format($subtotal, 2); ?> ر.ق</td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

    <!-- TOTALS + POLICY -->
    <div class="totals-section">
        <div class="return-policy">
            <strong>الاستبدال و الاسترجاع :</strong>
            يمكن الاستبدال والإسترجاع خلال فترة الـ 14 يوم من تاريخ أستلام السلعة.
        </div>

        <div class="totals-table">
            <div class="totals-row">
                <span class="t-label">السعر</span>
                <span><?= number_format($total, 2); ?> ر.ق</span>
            </div>
            <div class="totals-row">
                <span class="t-label">الضريبة</span>
                <span>0.00 ر.ق</span>
            </div>
            <div class="totals-grand">
                <span class="t-label">الاجمالي</span>
                <span class="t-amount"><?= number_format($total, 2); ?> ر.ق</span>
            </div>
        </div>
    </div>

    <!-- FOOTER -->
    <div class="inv-footer">
        <div>
            <div class="footer-thank">Thank you for purchase!</div>
            <div style="margin-top: 10px;" class="footer-contacts">
                <?= htmlspecialchars($email); ?><br>
                <?= htmlspecialchars($site); ?><br>
                <span dir="ltr">+974 <?= htmlspecialchars($phone); ?></span>
            </div>
        </div>

        <div class="sig-block">
            <div style="font-style: italic; font-size: 22px; color: #333; font-family: Georgia, serif;">Signature</div>
            <div class="sig-label">توقيع البائع</div>
        </div>
    </div>

    <div class="bottom-strip"></div>

</div>

<button class="print-btn" onclick="window.print()">
    <svg viewBox="0 0 24 24"><path d="M6 9V2h12v7M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>
    طباعة الفاتورة
</button>

</body>
</html>
<?php $conn->close(); ?>