<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: text/html; charset=utf-8');

$conn = mysqli_connect("localhost", "cdagvlmy_Globee", "A122%133z.", "cdagvlmy_Globee");

$order_id = isset($_GET['order_id']) ? (int)$_GET['order_id'] : 0;
$user_id  = isset($_GET['user_id'])  ? (int)$_GET['user_id']  : 0;
$store_id = isset($_GET['store_id']) ? (string)$_GET['store_id'] : 1;
$view_type = isset($_GET['view']) ? $_GET['view'] : 'seller';

$email = "";
$site  = "";
$phone = "";
$name  = "";

// ── Store Info + Theme Colors ──
switch ($store_id) {
    case '2':
        $name  = "Global Farm";
        $email = "info@gfnursery.net";
        $site  = "gfnursery.net";
        $phone = "+97477991225";
        // Global Farm: olive green + dark brown + dark blue
        $theme = [
            'primary'    => '#5A7A2E',   // olive green (header bg, total bar, body header)
            'secondary'  => '#2C4A1E',   // dark green (skew panels, left blocks)
            'accent'     => '#8B6914',   // warm gold accent
            'text_light' => '#FFFFFF',
            'divider'    => '#A8C068',
        ];
        break;
    case '3':
        $name  = "Golden Eagle Stores";
        $email = "info@ges.qa";
        $site  = "ges.qa";
        $phone = "44414156";
        // Golden Eagle: deep gold + dark navy
        $theme = [
            'primary'    => '#1A6BB5',   // الأزرق الرئيسي (كان ذهبي داكن)
            'secondary'  => '#0D4A8A',   // الأزرق الداكن (كان كحلي غامق)
            'accent'     => '#F5A623',   // الذهبي/البرتقالي (كان ذهبي فاتح)
            'text_light' => '#FFFFFF',   // ثابت
            'divider'    => '#F5A623',   // الذهبي (كان نفس الـ accent)
        ];
        break;
    case '4':
        $name  = "البدع للخدمات البيطرية";
        $email = "info@albadaa-qatar.com";
        $site  = "albadaa-qatar.com";
        $phone = "+974 30773570";
        // Albadaa: نيلي داكن + أزرق متوسط + لمسات فاتحة - من الشعار
        $theme = [
            'primary'    => '#2D2E8B',   // النيلي الداكن الأساسي من الشعار
            'secondary'  => '#1B1C6E',   // أعمق درجة للتباين
            'accent'     => '#5A5CC7',   // أزرق فاتح من الشعار
            'text_light' => '#FFFFFF',
            'divider'    => '#7B7EE0',   // لون فاتح للفاصل
        ];
        break;

    default:
        $name  = "MartIt";
        $email = "info@martit.com";
        $site  = "MartIt.com";
        $phone = "71402613";
        // MartIt: original red + dark navy
        $theme = [
            'primary'    => '#df2d23',
            'secondary'  => '#1B2A4A',
            'accent'     => '#df2d23',
            'text_light' => '#FFFFFF',
            'divider'    => '#cccccc',
        ];
        break;
}

// Build WHERE clause based on view type
if ($view_type === 'customer') {
    // Customer view: fetch all orders with same oid (combined invoice from all sellers)
    $d1 = "Orders.oid = '$order_id'";
} else {
    // Seller view: filter by oid + uid so seller sees only their own items
    if ($order_id && $user_id) {
        $d1 = "Orders.oid = '$order_id' AND Orders.uid = '$user_id'";
    } elseif ($order_id) {
        // Fallback: if only order_id provided, use it as primary key (id)
        $d1 = "Orders.id = '$order_id'";
    } else {
        $d1 = "Orders.uid = '$user_id'";
    }
}

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
    $decoded_items  = json_decode($row['items'], true) ?? [];
    foreach ($decoded_items as $decoded) {
        $price    = (float)($decoded['price']    ?? 0);
        $qty      = (int)  ($decoded['quantity'] ?? 0);
        $subtotal = $price * $qty;
        $total   += $subtotal;
    }
}
?>

<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=3.0, user-scalable=yes">
    <title>Bootstrap demo</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        /* ── Dynamic Theme Variables ── */
        :root {
            --color-primary:   <?= $theme['primary'] ?>;
            --color-secondary: <?= $theme['secondary'] ?>;
            --color-accent:    <?= $theme['accent'] ?>;
            --color-text:      <?= $theme['text_light'] ?>;
            --color-divider:   <?= $theme['divider'] ?>;
        }

        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Cairo', sans-serif;
            background: #fff;
            direction: rtl;
        }

        .invoice {
            width: 100%;
            max-width: 210mm;
            min-height: 297mm;
            background: white;
            margin: 0 auto;
            position: relative;
        }

        /* ── HEADER ── */
        .inv-header {
            position: relative;
            height: 160px;
            overflow: hidden;
            background: var(--color-primary);
        }

        .header-left, .header-left-skew {
            position: absolute;
            top: 0;
            left: -30px !important;
            width: 56%;
            height: 100%;
            background: var(--color-secondary);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 30px 36px;
            border-radius: 0 10px 20px 0;
            border: 3px solid #fff;
        }

        .header-left {
            background: transparent;
            border: none !important;
        }

        .header-left h1 {
            color: var(--color-text);
            font-size: 36px;
            font-weight: 900;
            line-height: 1.3;
            text-align: center;
        }

        .header-right {
            position: absolute;
            top: 0;
            right: 0;
            width: 50%;
            height: 100%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 20px;
        }

        .header-left-skew {
            transform: skewX(20deg);
            left: -30px !important;
        }

        .header-logo {
            width: 80px;
            height: 80px;
            background: #fff;
            border-radius: 20px;
            object-fit: contain;
        }

        .header-brand {
            color: var(--color-text);
            font-size: 22px;
            font-weight: 800;
        }

        /* ── Customer Details ── */
        .divider {
            width: 30px;
            height: 3px;
            background: var(--color-divider);
        }

        .cust-total-text {
            color: var(--color-primary) !important;
        }

        .print-layout-table {
            width: 100%;
            border-collapse: collapse;
        }

        /* ── Invoice Body (columns header) ── */
        .inv-body {
            position: relative;
            height: 50px;
            overflow: hidden;
            background: var(--color-secondary);
        }

        .inv-right, .inv-right-skew {
            position: absolute;
            top: 0;
            right: -30px !important;
            width: 40%;
            height: 100%;
            background: var(--color-primary);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 30px 36px;
            border-radius: 10px 0 0 30px;
        }

        .inv-right {
            background: transparent !important;
            color: var(--color-text);
            top: -5px;
            right: -20px !important;
        }

        .inv-right-skew {
            transform: skewX(-20deg);
            left: -30px !important;
        }

        .inv-left {
            position: absolute;
            top: -5px;
            left: 0px !important;
            width: 64%;
            height: 100%;
            background: var(--color-secondary);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 30px;
            border-radius: 0 10px 20px 0;
            color: var(--color-text);
        }

        .inv-left div {
            margin: 0 30px;
        }

        .item-row .itemname {
            width: 35%;
            padding: 10px;
        }

        .item-row {
            border-bottom: 1px solid #ddd;
        }

        .fx-items {
            width: 65%;
            display: flex;
        }

        .fx-items div {
            flex-grow: 1;
            text-align: center;
            display: flex;
            justify-content: center;
            align-items: center;
        }

        /* ── Invoice Total ── */
        .inv-total {
            position: relative;
            height: 50px;
            overflow: hidden;
            background: var(--color-primary);
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: var(--color-text);
            padding: 0 20px;
        }

        .inv-footer-design {
            background: var(--color-secondary) !important;
            padding: 5px 0 !important;
            height: 30px;
        }

        tfoot tr td .footer {
            position: fixed !important;
            bottom: 0;
            left: 0;
            right: 0;
            height: 20px;
            width: 100%;
            overflow: hidden;
            background: var(--color-primary);
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: var(--color-text);
            padding: 0 20px;
        }

        .footer-left, .footer-left-skew {
            position: absolute;
            bottom: 0;
            right: -30px !important;
            width: 56%;
            height: 100%;
            background: var(--color-secondary);
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 30px 36px;
        }

        .footer-left {
            background: transparent;
            border: none !important;
        }

        .footer-left-skew {
            transform: skewX(50deg);
            left: -30px !important;
        }

        @media print {
            @page { size: A4; margin: 0; }
            body { margin: 0; }
            .invoice { width: 100%; height: 100%; box-shadow: none; }
            .table-header { width: 100%; border-collapse: collapse; }
            .table-items thead { display: table-header-group; }
            .table-items tfoot { display: table-footer-group; }
        }

        @media screen and (max-width: 600px) {
            .inv-cust-details {
                flex-direction: column !important;
                padding: 20px !important;
            }
            
            .inv-cust-details .cust-left,
            .inv-cust-details .cust-right {
                width: 100% !important;
                margin-bottom: 20px;
            }
        
            .inv-header {
                height: 130px;
            }
        
            .header-logo {
                width: 60px;
                height: 60px;
            }
        
            .header-left h1 {
                font-size: 24px;
            }
        }
    </style>
  </head>
  <body dir="rtl">

    <div class="invoice">

        <!-- ===== جدول 1: الهيدر وبيانات العميل - يظهر مرة واحدة فقط ===== -->
        <table class="table-header" style="width:100%; border-collapse:collapse;">
            <tbody>
                <tr>
                    <td>
                        <div class="inv-header">
                            <div class="header-left-skew"></div>
                            <div class="header-left"><h1>فاتورة <br> رقم <?=$order_id;?></h1></div>
                            <div class="header-right">
                                <img src="../sys/assets/img/<?= $store_id; ?>.png?k=<?= time(); ?>" alt="<?= htmlspecialchars($name) ?>" class="header-logo">
                            </div>
                        </div>

                        <div class="inv-cust-details d-flex p-5">
                            <div class="cust-left w-50">
                                <div class="cust-total-text fs-5">المبلغ الإجمالي</div>
                                <div class="cust-total-price fs-4 fw-bold"><?=$total;?> QAR</div>
                                <div class="divider my-2"></div>
                                <div class="bill-no">رقم الفاتورة: <?=$order_id;?></div>
                                <div class="bill-date">تاريخ الفاتورة: <?=implode('-', array_reverse(explode('-', explode(' ', $items[0]['created_at'])[0])))?></div>
                            </div>
                            <div class="cust-right w-50">
                                <div class="cust-total-text fs-5">إسم المشتري:</div>
                                <div class="cust-total-price fs-4 fw-bold"><?=$items[0]['ship_fullname'];?></div>
                                <div class="divider my-2"></div>
                                <div class="bill-mob">رقم التليفون: <?=$items[0]['ship_mobile'];?></div>
                                <div class="bill-email">البريد الإلكتروني: <?=$items[0]['ship_email'];?></div>
                                <div class="bill-address">العنوان: منطقة رقم <?=$items[0]['ship_zone'];?>, شارع رقم <?=$items[0]['ship_street'];?>, مبنى رقم <?=$items[0]['ship_building'];?>, <?=$items[0]['ship_country'];?><div>
                            </div>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>

        <!-- ===== جدول 2: الأصناف - يكرر عناوين الأعمدة في كل صفحة ===== -->
        <table class="table-items" style="width:100%; border-collapse:collapse;">

            <!-- thead بيتكرر تلقائياً في كل صفحة عند الطباعة -->
            <thead>
                <tr>
                    <td>
                        <div class="inv-body">
                            <div class="inv-left">
                                <div>الكمية</div>
                                <div>السعر</div>
                                <div>الإجمالي</div>
                            </div>
                            <div class="inv-right-skew"></div>
                            <div class="inv-right">إسم المنتج</div>
                        </div>
                    </td>
                </tr>
            </thead>

            <tfoot>
                <tr>
                    <td>
                        <div class="footer">
                            <div class="footer-left-skew"></div>
                            <div class="footer-left"></div>
                            <div class="footer-right"></div>
                        </div>
                    </td>
                </tr>
            </tfoot>

            <tbody>
                <?php
                    $total = 0;
                    foreach ($items as $row) {
                        $decoded_items = json_decode($row['items'], true) ?? [];
                        
                        foreach ($decoded_items as $decoded) {
                            $price    = (float)($decoded['price']    ?? 0);
                            $qty      = (int)  ($decoded['quantity'] ?? 0);
                            $subtotal = $price * $qty;
                            $total   += $subtotal;
                    ?>
                            <tr>
                                <td>
                                    <div class="item-row d-flex">
                                        <div class="text-center itemname"><?= htmlspecialchars($decoded['name'] ?? '—'); ?></div>
                                        <div class="fx-items">
                                            <div><?= $qty; ?></div>
                                            <div style="background: #F9F8F9;"><?= number_format($price); ?> ر.ق</div>
                                            <div><?= number_format($subtotal); ?> ر.ق</div>
                                        </div>
                                    </div>
                                </td>
                            </tr>
                    <?php
                        }
                    }
                    ?>

                <tr>
                    <td>
                        <div class="inv-total">
                            <div class="total-right">الإجمالي</div>
                            <div class="total-peicx"><?=number_format($total);?> ر.ق</div>
                        </div>
                    </td>
                </tr>

            </tbody>
        </table>
        
    </div>
    
  </body>
</html>