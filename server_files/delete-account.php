<?
$name = "";
$email = "";
if (isset($_GET['store_id']))
{
    switch ($_GET['store_id']) {
        case '2':
            $name = "GlobalFarm";
            $email = "info@gfnursery.net";
            break;
        case '3':
            $name = "Golden Eagle Stores";
            $email = "info@ges.qa";
            break;
        default:
            $name = "MartIt";
            $email = "info@globee-trading.com";
            break;
    }
} else {
    $name = "MartIt";
    $email = "info@globee-trading.com";
}



?>

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Account Deletion Request - <?=$name;?></title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 700px;
      margin: 40px auto;
      padding: 20px;
      background: #f7f9fc;
      color: #333;
      line-height: 1.6;
    }
    h1 {
      color: #2c3e50;
    }
    p {
      margin-bottom: 1em;
    }
    ul {
      margin-left: 20px;
    }
    a {
      color: #2980b9;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h1>Account Deletion Request</h1>
  <p>Welcome to <strong><?=$name;?></strong> data deletion page.</p>
  <p>If you want to delete your account and all associated data from <strong><?=$name;?></strong>, please follow the steps below:</p>
  <ol>
    <li>Send an email to: <a href="mailto:<?=$email;?>"><?=$email;?></a> with the subject <em>"Delete My Account"</em>.</li>
    <li>Include your username or email address registered with the app.</li>
    <li>Our team will process your request within 7 business days.</li>
    <li>We will delete all personal data linked to your account, including profile information, usage data, and settings.</li>
    <li>Some data may be retained for legal or security reasons as required by law.</li>
  </ol>
  <p>If you have any questions, please contact us at <a href="mailto:<?=$email;?>"><?=$email;?></a>.</p>
</body>
</html>
