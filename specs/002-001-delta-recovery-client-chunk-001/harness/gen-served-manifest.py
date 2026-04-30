#!/usr/bin/env python3
"""
gen-served-manifest.py — assemble fixtures/canonical/served/manifest.json from
the source bytes under fixtures/canonical/source/ (T018).

Emits a manifest in canonical form (sorted keys, no insignificant whitespace,
UTF-8, no trailing newline) that conforms to contracts/manifest.schema.json.
The same canonical form is what the trust-root sidecar (T019) hashes.

Usage:
    gen-served-manifest.py [--block-height N] [--core-version V] [--created-at ISO]

By default the manifest's canonical_identity.created_at is set to "now" minus
seven days (per T043 — keeps the freshness predicate satisfied for the lifetime
of the synthetic fixture without needing daily regeneration).
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import struct
import sys
from pathlib import Path

PAGE_SIZE = 4096

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "fixtures" / "canonical" / "source"
SERVED = ROOT / "fixtures" / "canonical" / "served"


def sqlite_change_counter(path: Path) -> int:
    # SQLite header field at offset 24, 4-byte big-endian.
    header = path.open("rb").read(28)
    return struct.unpack(">I", header[24:28])[0]


def page_entries(file_path: Path) -> list[dict]:
    data = file_path.read_bytes()
    if len(data) % PAGE_SIZE != 0:
        raise SystemExit(
            f"sqlite_pages source must be a multiple of {PAGE_SIZE} bytes; "
            f"{file_path} is {len(data)} bytes"
        )
    out = []
    for offset in range(0, len(data), PAGE_SIZE):
        chunk = data[offset:offset + PAGE_SIZE]
        out.append({
            "offset": offset,
            "hash": hashlib.sha256(chunk).hexdigest(),
        })
    return out


def whole_file_entry(file_path: Path, manifest_path: str) -> dict:
    data = file_path.read_bytes()
    return {
        "entry_kind": "whole_file",
        "hash": hashlib.sha256(data).hexdigest(),
        "path": manifest_path,
    }


def canonical_form(obj) -> bytes:
    # sorted keys, no insignificant whitespace, UTF-8, no trailing newline.
    return json.dumps(
        obj,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--block-height", type=int, default=3806626)
    ap.add_argument("--core-version", default="0.21.18-fixture")
    ap.add_argument(
        "--created-at",
        default=None,
        help="RFC 3339 UTC; default: now - 7 days",
    )
    args = ap.parse_args()

    if args.created_at is None:
        # Use a recent-but-not-now timestamp (7 days back). Strip microseconds
        # so the canonical form is stable across regenerations within the day.
        ts = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=7)
        ts = ts.replace(microsecond=0)
        created_at = ts.isoformat().replace("+00:00", "Z")
    else:
        created_at = args.created_at

    main_sqlite = SOURCE / "pocketdb" / "main.sqlite3"
    block_file = SOURCE / "blocks" / "000000.dat"
    chainstate_file = SOURCE / "chainstate" / "CURRENT"
    for p in (main_sqlite, block_file, chainstate_file):
        if not p.is_file():
            raise SystemExit(f"missing source: {p}")

    manifest = {
        "canonical_identity": {
            "block_height": args.block_height,
            "created_at": created_at,
            "pocketnet_core_version": args.core_version,
        },
        "entries": [
            {
                "change_counter": sqlite_change_counter(main_sqlite),
                "entry_kind": "sqlite_pages",
                "pages": page_entries(main_sqlite),
                "path": "pocketdb/main.sqlite3",
            },
            whole_file_entry(block_file, "blocks/000000.dat"),
            whole_file_entry(chainstate_file, "chainstate/CURRENT"),
        ],
        "format_version": 1,
        "trust_anchors": [],
    }

    SERVED.mkdir(parents=True, exist_ok=True)
    body = canonical_form(manifest)
    manifest_path = SERVED / "manifest.json"
    manifest_path.write_bytes(body)

    print(f"wrote {manifest_path.relative_to(ROOT)} ({len(body)} bytes, canonical-form)")
    print(f"  block_height={args.block_height} core_version={args.core_version} created_at={created_at}")
    print(f"  entries={len(manifest['entries'])} pages_in_main_sqlite3={len(manifest['entries'][0]['pages'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
