#!/usr/bin/env python3
"""Copy missing store images to S3 as WebP.

Dry-run is the default. Nothing is uploaded unless --execute is passed.
An object that already exists in the martit bucket is never overwritten.
The source bucket is only read.

Destination key:
    store_{store_id}/{item_id}/{number}.webp

If the same image already exists under the item idx, it is treated as
present and is not uploaded again.

Sources:
    VPS files under --source / MARTIT_MEDIA_ROOT
    Store 2, when --source-s3-bucket is set:
        s3://{bucket}/items/{item_id|idx}/{number}.{ext}
        The live URL host is globalfarmnursery.s3.ap-south-1.amazonaws.com.

Credentials and the database password come from the environment only.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

IMAGE_EXTS = (".webp", ".jpg", ".jpeg", ".png", ".gif")
VIDEO_EXTS = (".mp4", ".mov", ".avi")
EXT_RANK = {ext: index for index, ext in enumerate(IMAGE_EXTS)}
STORES = ("1", "2", "3", "4", "5")
BUCKET = "martit"
REGION = "ap-south-1"


@dataclass(frozen=True)
class Job:
    store_id: str
    item_id: str
    idx: str
    number: int
    source_label: str
    local_path: Path | None = None
    source_bucket: str = ""
    source_key: str = ""

    @property
    def key(self) -> str:
        return f"store_{self.store_id}/{self.item_id}/{self.number}.webp"

    @property
    def idx_key(self) -> str:
        if not self.idx or self.idx == self.item_id:
            return ""
        return f"store_{self.store_id}/{self.idx}/{self.number}.webp"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Upload missing store images to S3 as WebP.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="Print the plan only (default).")
    mode.add_argument("--execute", action="store_true", help="Upload missing keys. Never overwrites.")
    parser.add_argument("--store", default="", help="One store id, 1-5. Default: all.")
    parser.add_argument("--source", default=os.environ.get("MARTIT_MEDIA_ROOT", ""), help="VPS image root.")
    parser.add_argument(
        "--source-s3-bucket",
        default="",
        help="Read store 2 images from this bucket, under items/. Example: globalfarmnursery",
    )
    parser.add_argument("--state", default="sync_store_images_state.jsonl", help="Resume log.")
    parser.add_argument("--failed-csv", default="sync_store_images_failed.csv")
    parser.add_argument("--batch", type=int, default=200)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument(
        "--sample",
        type=int,
        default=0,
        help="Max missing keys to print per store. 0 prints every missing key.",
    )
    args = parser.parse_args()
    if not args.execute:
        args.dry_run = True
    if args.store and args.store not in STORES:
        parser.error("--store must be 1, 2, 3, 4, or 5")
    if args.workers < 1 or args.workers > 10:
        parser.error("--workers must be from 1 to 10")
    if not args.source and not args.source_s3_bucket:
        parser.error("Pass --source and/or --source-s3-bucket")
    return args


def db_connect():
    missing = [
        name
        for name in ("MARTIT_DB_HOST", "MARTIT_DB_USER", "MARTIT_DB_PASSWORD", "MARTIT_DB_NAME")
        if not os.environ.get(name)
    ]
    if missing:
        sys.exit("Missing environment variables: " + ", ".join(missing))
    import pymysql

    return pymysql.connect(
        host=os.environ["MARTIT_DB_HOST"],
        user=os.environ["MARTIT_DB_USER"],
        password=os.environ["MARTIT_DB_PASSWORD"],
        database=os.environ["MARTIT_DB_NAME"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
    )


def media_numbers(media: str) -> list[int]:
    numbers: list[int] = []
    for part in (media or "").split(","):
        token = part.strip().split("?")[0].split("/")[-1]
        if not token:
            continue
        suffix = Path(token.lower()).suffix
        if suffix in VIDEO_EXTS:
            continue
        digits = "".join(ch for ch in Path(token).stem if ch.isdigit())
        number = int(digits) if digits else len(numbers) + 1
        if number < 1:
            number = len(numbers) + 1
        if number not in numbers:
            numbers.append(number)
    return numbers


def candidate_sources(root: Path, store_id: str, item_id: str, idx: str, number: int) -> Iterable[Path]:
    folders = [item_id]
    if idx and idx not in folders:
        folders.append(idx)
    prefixes = [
        root / f"store_{store_id}",
        root,
        root / "GES" if store_id == "3" else None,
        root / "items" if store_id == "2" else None,
    ]
    for prefix in prefixes:
        if prefix is None:
            continue
        for folder in folders:
            for ext in IMAGE_EXTS:
                yield prefix / folder / f"{number}{ext}"


def find_local_source(root: Path | None, store_id: str, item_id: str, idx: str, number: int) -> Path | None:
    if root is None:
        return None
    for path in candidate_sources(root, store_id, item_id, idx, number):
        if path.is_file():
            return path
    return None


def list_bucket_keys(client, bucket: str, prefix: str) -> set[str]:
    found: set[str] = set()
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get("Contents", []):
            found.add(item["Key"])
    return found


def index_nursery_keys(keys: Iterable[str]) -> dict[tuple[str, int], str]:
    """Map (folder, image number) to the best items/ object key."""
    best: dict[tuple[str, int], tuple[int, str]] = {}
    for key in keys:
        parts = key.split("/")
        if len(parts) < 3 or parts[0] != "items":
            continue
        folder = parts[1]
        suffix = Path(parts[-1].lower()).suffix
        if suffix not in EXT_RANK:
            continue
        digits = "".join(ch for ch in Path(parts[-1]).stem if ch.isdigit())
        if not digits:
            continue
        number = int(digits)
        rank = EXT_RANK[suffix]
        current = best.get((folder, number))
        if current is None or rank < current[0]:
            best[(folder, number)] = (rank, key)
    return {pair: key for pair, (_, key) in best.items()}


def nursery_source(index: dict[tuple[str, int], str], item_id: str, idx: str, number: int) -> str:
    for folder in (item_id, idx):
        if not folder:
            continue
        key = index.get((folder, number))
        if key:
            return key
    return ""


def load_rows(store: str) -> list[dict]:
    stores = (store,) if store else STORES
    placeholders = ",".join(["%s"] * len(stores))
    sql = f"""
        SELECT id, idx, store_id, media
        FROM Items
        WHERE store_id IN ({placeholders})
    """
    connection = db_connect()
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, stores)
            return list(cursor.fetchall())
    finally:
        connection.close()


def build_jobs(
    rows: list[dict],
    root: Path | None,
    nursery_index: dict[tuple[str, int], str],
    nursery_bucket: str,
) -> tuple[dict[str, int], list[Job], list[Job]]:
    item_counts = {store: 0 for store in STORES}
    ready: list[Job] = []
    missing_source: list[Job] = []
    for row in rows:
        store_id = str(row["store_id"]).strip()
        item_id = str(row["id"]).strip()
        idx = str(row.get("idx") or "").strip()
        item_counts[store_id] = item_counts.get(store_id, 0) + 1
        for number in media_numbers(str(row.get("media") or "")):
            source_key = ""
            if store_id == "2" and nursery_bucket:
                source_key = nursery_source(nursery_index, item_id, idx, number)
            if source_key:
                ready.append(
                    Job(
                        store_id,
                        item_id,
                        idx,
                        number,
                        f"s3://{nursery_bucket}/{source_key}",
                        source_bucket=nursery_bucket,
                        source_key=source_key,
                    )
                )
                continue
            local = find_local_source(root, store_id, item_id, idx, number)
            if local is not None:
                ready.append(Job(store_id, item_id, idx, number, str(local), local_path=local))
                continue
            missing_source.append(Job(store_id, item_id, idx, number, "not found"))
    return item_counts, ready, missing_source


def s3_client():
    for name in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
        if not os.environ.get(name):
            sys.exit(f"Missing environment variable: {name}")
    import boto3

    return boto3.client("s3", region_name=os.environ.get("AWS_DEFAULT_REGION", REGION))


def list_existing_keys(client, store_ids: Iterable[str]) -> set[str]:
    return set().union(*(list_bucket_keys(client, BUCKET, f"store_{store_id}/") for store_id in store_ids))


def covered(job: Job, existing: set[str]) -> bool:
    return job.key in existing or bool(job.idx_key and job.idx_key in existing)


def load_state(path: Path) -> dict[str, str]:
    state: dict[str, str] = {}
    if not path.exists():
        return state
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        state[row["key"]] = row["status"]
    return state


def append_state(path: Path, key: str, status: str, detail: str = "") -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps({"key": key, "status": status, "detail": detail}) + "\n")


def append_failed(path: Path, key: str, reason: str) -> None:
    new_file = not path.exists()
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        if new_file:
            writer.writerow(["key", "reason"])
        writer.writerow([key, reason])


def to_webp(data: bytes, suffix: str) -> tuple[bytes, int]:
    original = len(data)
    if suffix == ".webp":
        return data, original
    from PIL import Image, ImageOps

    with Image.open(io.BytesIO(data)) as image:
        image = ImageOps.exif_transpose(image)
        if image.mode not in ("RGB", "RGBA"):
            image = image.convert("RGB")
        if image.width > 1600:
            height = max(1, round(image.height * (1600 / image.width)))
            image = image.resize((1600, height), Image.Resampling.LANCZOS)
        buffer = io.BytesIO()
        image.save(buffer, format="WEBP", quality=80, method=6)
        return buffer.getvalue(), original


def read_source(client, job: Job) -> tuple[bytes, str]:
    if job.local_path is not None:
        return job.local_path.read_bytes(), job.local_path.suffix.lower()
    response = client.get_object(Bucket=job.source_bucket, Key=job.source_key)
    return response["Body"].read(), Path(job.source_key).suffix.lower()


def object_exists(client, key: str) -> bool:
    from botocore.exceptions import ClientError

    try:
        client.head_object(Bucket=BUCKET, Key=key)
        return True
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code", "")
        if code in ("404", "NoSuchKey", "NotFound"):
            return False
        raise


def upload_once(client, job: Job, payload: bytes) -> None:
    client.put_object(
        Bucket=BUCKET,
        Key=job.key,
        Body=payload,
        ContentType="image/webp",
        CacheControl="public, max-age=31536000",
        IfNoneMatch="*",
    )


def upload_job(client, job: Job) -> tuple[str, str, int, int]:
    if object_exists(client, job.key) or (job.idx_key and object_exists(client, job.idx_key)):
        return job.key, "skipped", 0, 0
    payload, original = to_webp(*read_source(client, job))
    delay = 1.0
    last_error = "upload failed"
    for attempt in range(3):
        try:
            if object_exists(client, job.key):
                return job.key, "skipped", 0, 0
            upload_once(client, job, payload)
            return job.key, "uploaded", original, len(payload)
        except Exception as exc:
            code = getattr(exc, "response", {}).get("Error", {}).get("Code", "") if hasattr(exc, "response") else ""
            if code in ("PreconditionFailed", "ConditionalRequestConflict"):
                return job.key, "skipped", 0, 0
            last_error = str(exc)
            if attempt < 2:
                time.sleep(delay)
                delay *= 2
    raise RuntimeError(last_error)


def print_dry_run(
    item_counts: dict[str, int],
    ready: list[Job],
    missing_source: list[Job],
    existing: set[str],
    sample: int,
) -> None:
    stats = {
        store: {"items": item_counts.get(store, 0), "expected": 0, "on_s3": 0, "missing": 0}
        for store in STORES
    }
    missing_by_store: dict[str, list[Job]] = {store: [] for store in STORES}
    for job in ready:
        row = stats.setdefault(job.store_id, {"items": 0, "expected": 0, "on_s3": 0, "missing": 0})
        row["expected"] += 1
        if covered(job, existing):
            row["on_s3"] += 1
        else:
            row["missing"] += 1
            missing_by_store.setdefault(job.store_id, []).append(job)
    for job in missing_source:
        row = stats.setdefault(job.store_id, {"items": 0, "expected": 0, "on_s3": 0, "missing": 0})
        row["expected"] += 1
        row["missing"] += 1
        missing_by_store.setdefault(job.store_id, []).append(job)

    print("DRY RUN. No uploads.")
    print(f"{'store':<8}{'items_in_db':>14}{'expected_keys':>16}{'already_on_s3':>16}{'missing':>10}")
    for store, row in stats.items():
        if row["items"] or row["expected"]:
            print(
                f"{store:<8}{row['items']:>14}{row['expected']:>16}{row['on_s3']:>16}{row['missing']:>10}"
            )
    for store, jobs in missing_by_store.items():
        if not jobs:
            continue
        shown = jobs if sample <= 0 else jobs[:sample]
        print(f"\nstore {store} missing ({len(jobs)}):")
        for job in shown:
            print(f"  {job.key}  <=  {job.source_label}")
        hidden = len(jobs) - len(shown)
        if hidden:
            print(f"  ... {hidden} more. Pass --sample 0 to print every missing key.")


def main() -> None:
    args = parse_args()
    root = Path(args.source) if args.source else None
    if root is not None and not root.is_dir():
        sys.exit(f"Source directory does not exist: {root}")

    store_ids = (args.store,) if args.store else STORES
    client = s3_client()
    nursery_index: dict[tuple[str, int], str] = {}
    if args.source_s3_bucket and (not args.store or args.store == "2"):
        nursery_index = index_nursery_keys(list_bucket_keys(client, args.source_s3_bucket, "items/"))

    rows = load_rows(args.store)
    item_counts, ready, missing_source = build_jobs(rows, root, nursery_index, args.source_s3_bucket)
    existing = list_existing_keys(client, store_ids)
    if args.dry_run:
        print_dry_run(item_counts, ready, missing_source, existing, args.sample)
        return

    state_path = Path(args.state)
    failed_path = Path(args.failed_csv)
    state = load_state(state_path)
    pending: list[Job] = []
    skipped = 0
    for job in ready:
        if covered(job, existing) or state.get(job.key) == "uploaded":
            skipped += 1
            continue
        pending.append(job)

    uploaded = 0
    failed = 0
    bytes_before = 0
    bytes_after = 0
    for job in missing_source:
        failed += 1
        append_state(state_path, job.key, "failed", job.source_label)
        append_failed(failed_path, job.key, job.source_label)

    for start in range(0, len(pending), args.batch):
        batch = pending[start : start + args.batch]
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(upload_job, client, job): job for job in batch}
            for future in as_completed(futures):
                job = futures[future]
                try:
                    key, status, before, after = future.result()
                    append_state(state_path, key, status)
                    if status == "uploaded":
                        uploaded += 1
                        bytes_before += before
                        bytes_after += after
                    else:
                        skipped += 1
                except Exception as exc:
                    failed += 1
                    append_state(state_path, job.key, "failed", str(exc))
                    append_failed(failed_path, job.key, str(exc))

    saved_mb = max(0, bytes_before - bytes_after) / (1024 * 1024)
    print(
        f"scanned={len(ready) + len(missing_source)} skipped={skipped} uploaded={uploaded} "
        f"failed={failed} saved_mb={saved_mb:.2f}"
    )


if __name__ == "__main__":
    main()
