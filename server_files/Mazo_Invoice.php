<?include('config.php');
$uid = "";
$oid = "";
$custId = "";
$uoQuery = "";
$total = 0;

$lang = '';

if (isset($_GET['lang']))
{
    $lang = $_GET['lang'];
}
$rol = array();
$langoi = $conx->query("SELECT $lang FROM Languages");
while($rows=mysqli_fetch_array($langoi)) {$rol[]=$rows;}


if (isset($_GET['uid'])) {
    $uid = $_GET['uid'];
}


if (isset($_GET['oid'])) {
    $oid = $_GET['oid'];
}

if (isset($_GET['shipId'])) {
    $shipId = $_GET['shipId'];
}

if (isset($_GET['custId'])) {
    $custId = $_GET['custId'];
}

$uoQuery = "WHERE Cart.order_id = '$oid'";
if (!empty($uid)) {
    // تحقق إن البائع له منتجات فعلًا
    $check = $conx->query("SELECT COUNT(*) as cnt FROM Cart WHERE order_id = '$oid' AND user_id = '$uid'")->fetch_assoc();
    if ($check['cnt'] > 0) {
        $uoQuery = "WHERE Cart.order_id = '$oid' AND Cart.user_id = '$uid'";
    }
}


?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">

    <title>Globee Invoice</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css" integrity="sha512-1ycn6IcaQQ40/MKBW2W4Rhis/DbILU74C1vSrLJxCq57o941Ym01SwNsOMqvEBFlcgUa6xLiPY/NS5R+E6ztJQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Poppins:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;0,800;0,900&display=swap');
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@200..1000&display=swap');
        .bred {
            border: 2px solid red;
        }
        * {
            /*font-family: "Poppins", sans-serif;*/
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body:dir(rtl) * {
            font-family: 'Cairo', sans-serif;
        }
        
        body:dir(ltr) * {
            font-family: 'Poppins', sans-serif;
        }


        html, body {
    width: 100%;
    height: 100%;
    min-height: 100vh;
    
}
        .invoice-box {
    max-width: 800px;
    margin: 0 auto;
    min-height: 100vh; /* ✅ أضف دي بدل height */
    position: relative;
    overflow: auto;
    scrollbar-width: none;
    -ms-overflow-style: none;
}

        
        .invoice-box::-webkit-scrollbar {
            display: none; /* Chrome, Safari, Opera */
        }

        .logoF {
            position: fixed;
            top: 100px;
        }

        .logoF img {
            width: 300px;
            opacity: 0.2;
        }
        
        .info-comp img {
            border-radius:10px;
        }
        
        body[dir="rtl"] .logoF{
            left: -140px;
        }
        body[dir="rtl"] .logoF img{
            transform: rotate(100deg);
        }
        
        body[dir="ltr"] .logoF{
            right: -140px;
        }
        body[dir="ltr"] .logoF img{
            transform: rotate(-100deg);
        }

        h1 {
            font-size: 60px;
        }

        .inv-footer {
    position: fixed;
    bottom: 0;
    left: 0;
    width: 100%;
    padding: 20px;
    background-color: #fff;
    border-top: 2px dashed #ccc;
    text-align: center;
    font-size: 12px;
    color: #888;
    z-index: 9999;
}




        /* Style for printing */
        @media print {
            .invoice-box {
                overflow: visible;
                max-width: 1000px;
            }

            /* To ensure footer appears on every page */
            .inv-footer {
                position: fixed;
                bottom: 0;
                width: 100%;
            }

            /* Page break after every 19 rows */
            tbody {
                counter-reset: rowCount;
            }
            tr {
                counter-increment: rowCount;
                page-break-inside: avoid;
                page-break-after: auto;
            }
            tr:nth-child(19n) {
                page-break-after: always;
            }

            thead {display: table-header-group;}
            tfoot {display: table-footer-group;}
        }
        
        @media screen and (max-width: 520px) {
            .mob-res {
                /*border:2px solid red;*/
                flex-direction:column;
            }
            .invoice-box {
                overflow-y: auto;
            }
        }
    </style>
</head>
<body dir="<?=$lang == 'arb' ? 'rtl' : 'ltr'?>">
    <?
    $shipDet = $conx->query("SELECT * FROM Shipping_Orders WHERE id = '$shipId' ")->fetch_array();
    
    $shipDate = $conx->query("SELECT created_at FROM Orders WHERE oid = '$oid' ")->fetch_array();
    
    $rox = array();
    $q = $conx->query("SELECT Cart.item_id, Cart.qtt, Cart.order_id, Cart.user_id, Items.name, Items.price FROM Cart JOIN Items ON Items.id = Cart.item_id $uoQuery");
    while($rows=mysqli_fetch_array($q)) {
        $rox[] = $rows;
    }
    ?>
    <div class="invoice-box">
        <div class="logoF">
            <img src="sys/uploads/Logo.png?k=<?=time();?>">
        </div>
        <div class="info-comp d-flex flex-column pt-5 px-3">
            <img src="sys/uploads/Logo.png?k=<?=time();?>" width="100px">
            <span class="fw-bold fs-4 mt-3"><?=$rol[84][$lang];?></span>
            <span class="text-muted"><?=$rol[84][$lang];?></span>
            <span class="text-muted"><?=$rol[85][$lang];?> : +974 77307831, +974 66762964</span>
        </div>
        <div class="inv pt-4 px-3">
            <h2 class="fw-bold"><?=$rol[86][$lang];?> </h2>
            <div class="d-flex mob-res justify-content-between mb-2">
                <span class="d-flex"><div class="fw-bold"><?=$rol[87][$lang];?> </div>&nbsp; #<?=$oid;?></span>
                <span class="d-flex"><div class="fw-bold"><?=$rol[88][$lang];?> </div>&nbsp; <?=explode(' ', $shipDate['created_at'])[0] ?? '';?></span>
            </div>
            <div class="d-flex mob-res justify-content-between mb-2">
                <span class="d-block "><span class="fw-bold" ><?=$rol[7][$lang];?> : </span> <?=$shipDet['Fullname'];?></span>
                <div class="d-flex justify-content-between">
                    <span class="d-block"><span class="fw-bold"><?=$rol[89][$lang];?> </span> <?=$shipDet['Country'];?></span>
                    <span class="d-block"><span class="fw-bold"><?=$rol[63][$lang];?> : </span> <?=$shipDet['City'];?></span>
                </div>
            </div>
            <div class="d-flex justify-content-between mb-2">
                <span style="font-size:13px;"><?=$rol[66][$lang];?> : <?=$shipDet['Building Number'];?></span>
                <span style="font-size:13px;"><?=$rol[65][$lang];?> : <?=$shipDet['Street Number'];?></span>
                <span style="font-size:13px;"><?=$rol[64][$lang];?> : <?=$shipDet['Zone Number'];?></span>
            </div>
            
            <!-- Single table structure -->
            <table class="table">
                <thead>
                    <tr style="font-size:13px;">
                        <th><?=$rol[90][$lang];?></th>
                        <th ><?=$rol[91][$lang];?></th>
                        <th><?=$rol[92][$lang];?></th>
                        <th><?=$rol[93][$lang];?></th>
                    </tr>
                </thead>
                <tbody style="font-size:12px;">
                    <?$i=1;foreach ($rox as $r) {
                    $itemTotal = $r['price'] * $r['qtt'];
                    $total += $itemTotal;
                    ?>
                    <tr>
                        <td><?=$i;?></td>
                        <td><?=$r['name'];?></td>
                        <td><?=$r['price'];?> <?=$rol[53][$lang];?></td>
                        <td><?=$r['price'] * 1;?> <?=$rol[53][$lang];?></td>
                    </tr>
                    <?$i++;}?>
                </tbody>
                <tr style="font-size:12px;font-weight:700;">
                    <td colspan="3"><?=$rol[93][$lang];?></td>
                    <td><?=$total;?> <?=$rol[53][$lang];?></td>
                </tr>
            </table>
        </div>
        
    </div>
    <br>
    <br>
    <br>
    <!-- Footer to be repeated on every page -->
    <div class="inv-footer" style="text-align: center; padding: 20px 0; color: #777; font-size: 14px;">
        © <?=date('Y')?> <?=$rol[0][$lang]?>. <?=$rol[94][$lang]?>.
    </div>

</body>
</html>
