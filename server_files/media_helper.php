<?php
/**
 * MartIt S3 product media URLs.
 * Pattern: https://martit.s3.ap-south-1.amazonaws.com/store_{store_id}/{idx}/{index}.{ext}
 * Falls back to item id when idx is empty.
 */
define('MARTIT_S3_BASE_URL', 'https://martit.s3.ap-south-1.amazonaws.com');

function martit_normalize_store_id($storeid)
{
    $storeid = trim((string)$storeid);
    return $storeid !== '' ? $storeid : '1';
}

function martit_resolve_item_path_key($idx, $itemId)
{
    $idx = trim((string)$idx);
    if ($idx !== '') {
        return $idx;
    }
    $itemId = trim((string)$itemId);
    return $itemId !== '' ? $itemId : '1';
}

/**
 * Resolve file extension from a media token (e.g. "1.mp4", "2.webp", full URL).
 * Images are always served as webp on S3.
 */
function martit_media_extension($token, $default = 'webp')
{
    $token = strtolower(trim((string)$token));
    if ($token === '') {
        return $default;
    }

    if (preg_match('/\.(webp|png|jpe?g|mp4|mov|avi)(?:\?|$)/i', $token, $m)) {
        $ext = strtolower($m[1]);
        if ($ext === 'jpg' || $ext === 'jpeg' || $ext === 'png') {
            return 'webp';
        }
        return $ext;
    }

    return $default;
}

function martit_item_media_url($storeid, $itemId, $index = 1, $idx = null, $ext = 'webp')
{
    $store = martit_normalize_store_id($storeid);
    $pathKey = martit_resolve_item_path_key($idx, $itemId);
    $index = (int)$index;
    if ($index < 1) {
        $index = 1;
    }
    $ext = ltrim(strtolower((string)$ext), '.');
    if ($ext === '') {
        $ext = 'webp';
    }

    return MARTIT_S3_BASE_URL . "/store_{$store}/{$pathKey}/{$index}.{$ext}";
}

function item_thumbnail_url($storeid, $itemId, $idx = null, $media = null)
{
    $ext = 'webp';
    if ($media !== null && $media !== '') {
        $parts = explode(',', (string)$media);
        $first = trim($parts[0]);
        $ext = martit_media_extension($first, 'webp');
    }
    return martit_item_media_url($storeid, $itemId, 1, $idx, $ext);
}

function build_item_media_urls($storeid, $itemId, $media, $img_url = null, $idx = null)
{
    $storeid = martit_normalize_store_id($storeid);
    $mediaFiles = array();

    if (!empty($media)) {
        $mediaArray = explode(',', $media);
        $sequentialIndex = 1;
        foreach ($mediaArray as $m) {
            $m = trim($m);
            if ($m === '') {
                continue;
            }

            $index = $sequentialIndex;
            if (preg_match('/(\d+)/', $m, $matches)) {
                $index = (int)$matches[1];
            }

            $ext = martit_media_extension($m, 'webp');
            $mediaFiles[] = martit_item_media_url($storeid, $itemId, $index, $idx, $ext);
            $sequentialIndex++;
        }
    }

    if (empty($mediaFiles)) {
        $mediaFiles[] = martit_item_media_url($storeid, $itemId, 1, $idx, 'webp');
    }

    return $mediaFiles;
}

function albadaa_thumbnail_url($itemId, $idx = null)
{
    return item_thumbnail_url('4', $itemId, $idx);
}
