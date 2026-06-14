<?php
/**
 * MartIt S3 product media URLs.
 * Pattern: https://martit.s3.ap-south-1.amazonaws.com/store_{store_id}/{idx}/{index}.png
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

function martit_item_media_url($storeid, $itemId, $index = 1, $idx = null)
{
    $store = martit_normalize_store_id($storeid);
    $pathKey = martit_resolve_item_path_key($idx, $itemId);
    $index = (int)$index;
    if ($index < 1) {
        $index = 1;
    }

    return MARTIT_S3_BASE_URL . "/store_{$store}/{$pathKey}/{$index}.png";
}

function item_thumbnail_url($storeid, $itemId, $idx = null)
{
    return martit_item_media_url($storeid, $itemId, 1, $idx);
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

            $mediaFiles[] = martit_item_media_url($storeid, $itemId, $index, $idx);
            $sequentialIndex++;
        }
    }

    if (empty($mediaFiles)) {
        $mediaFiles[] = martit_item_media_url($storeid, $itemId, 1, $idx);
    }

    return $mediaFiles;
}

function albadaa_thumbnail_url($itemId, $idx = null)
{
    return item_thumbnail_url('4', $itemId, $idx);
}
