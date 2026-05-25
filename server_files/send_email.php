<?
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
include('resend_auto/vendor/autoload.php');
$store_id = isset($_REQUEST['store_id']) ? $_REQUEST['store_id'] : '1';
$client_key = "";
$templateId = '';
$visitor_email = $_REQUEST['email'];
$otp = $_REQUEST['otp'];
$from = "";

switch ($store_id) {
    case '2':
        $from = "GlobalFarm <info@gfnursery.com>";
        $templateId = "verification-code-globalfarm";
        $client_key = "re_PoGrWWFb_49hPFzYb5evbFV8rKfAGfvMx";
        break;
    case '3':
        $from = "GES <info@ges.qa>";
        $templateId = "verification-code";
        $client_key = "re_KskMscxP_7tV476PH5aK7etvt6jGiusnK";
        break;
    default:
        $from = "MartIt <info@pos7d.site>";
        $templateId = "verification-code-martit";
        $client_key = "re_fPofZTeP_MNE88w8GV1MJ3CXxtn3r2RcC";
        break;
}

$resend = Resend::client($client_key);





$result = $resend->emails->send([
    'from' => $from,
    'to' => [$visitor_email],
    'template' => [
        'id' => $templateId,
        'variables' => [
            'otp' => $otp,
        ],
    ],
]);

echo "Email sent with template!\n";
echo "Email ID: " . $result->id . "\n";
?>