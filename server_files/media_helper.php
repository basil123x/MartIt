<?php
/**
 * Build product image URLs. Store 4 (Albadaa) uses martit store_4/{idx}/N.png (idx = S3 folder).
 */
function albadaa_s3_folder_id($itemIdx, $itemId)
{
    $idx = trim((string)$itemIdx);
    if ($idx !== '' && $idx !== '0') {
        return $idx;
    }
    return (string)$itemId;
}

function build_item_media_urls($storeid, $itemId, $media, $img_url = 'https://globee.b-cdn.net/', $itemIdx = '')
{
    $storeid = (string)$storeid;
    $itemId = (string)$itemId;
    $mediaFiles = array();

    if ($storeid === '4') {
        $folderId = albadaa_s3_folder_id($itemIdx, $itemId);
        if (!empty($media)) {
            $mediaArray = explode(',', $media);
            $index = 1;
            foreach ($mediaArray as $m) {
                $m = trim($m);
                if ($m === '') {
                    continue;
                }
                if (preg_match('/(\d+)/', $m, $matches)) {
                    $index = (int)$matches[1];
                }
                $mediaFiles[] = "https://martit.s3.ap-south-1.amazonaws.com/store_4/{$folderId}/{$index}.png";
                $index++;
            }
        }
        if (empty($mediaFiles)) {
            $mediaFiles[] = "https://martit.s3.ap-south-1.amazonaws.com/store_4/{$folderId}/1.png";
        }
        return $mediaFiles;
    }

    if (!empty($media)) {
        $mediaArray = explode(',', $media);
        foreach ($mediaArray as $m) {
            $m = trim($m);
            if ($m !== '') {
                $mediaFiles[] = $img_url . $itemId . '/' . $m;
            }
        }
    }
    return $mediaFiles;
}

function albadaa_thumbnail_url($itemId, $itemIdx = '')
{
    $folderId = albadaa_s3_folder_id($itemIdx, $itemId);
    return 'https://martit.s3.ap-south-1.amazonaws.com/store_4/' . $folderId . '/1.png';
}
