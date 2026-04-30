#!/usr/bin/env python3
"""
gen-served-chunks.py — split source bytes into chunks under
fixtures/canonical/served/files/ and produce both .zst and .gz pre-compressed
variants per chunk URL (T020, T021).

Layout produced:

  fixtures/canonical/served/files/pocketdb/main.sqlite3/pages/0     (no extension; placeholder)
  fixtures/canonical/served/files/pocketdb/main.sqlite3/pages/0.zst
  fixtures/canonical/served/files/pocketdb/main.sqlite3/pages/0.gz
  fixtures/canonical/served/files/pocketdb/main.sqlite3/pages/4096.zst
  ...
  fixtures/canonical/served/files/blocks/000000.dat.zst
  fixtures/canonical/served/files/blocks/000000.dat.gz
  fixtures/canonical/served/files/chainstate/CURRENT.zst
  fixtures/canonical/served/files/chainstate/CURRENT.gz

The bare (no-extension) chunk-path file is NOT created — the stub server only
ever serves the .zst or .gz variant per the request's Accept-Encoding (HTTP 406
otherwise). Storing the uncompressed source in served/ would invite the wrong
mental model.

Uses the system `zstd` and `gzip` CLIs so the byte format is exactly what a
production publisher would produce.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

PAGE_SIZE = 4096

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "fixtures" / "canonical" / "source"
SERVED_FILES = ROOT / "fixtures" / "canonical" / "served" / "files"


def compress_pair(src_bytes: bytes, dest_zst: Path, dest_gz: Path) -> None:
    dest_zst.parent.mkdir(parents=True, exist_ok=True)
    # Use the CLIs (long-form flags) so the at-rest bytes match what production
    # publishers using the same tools would produce.
    p_zst = subprocess.run(
        ["zstd", "-q", "--no-progress", "--ultra", "-22", "-c"],
        input=src_bytes,
        capture_output=True,
        check=True,
    )
    dest_zst.write_bytes(p_zst.stdout)
    p_gz = subprocess.run(
        ["gzip", "-9c", "-n"],
        input=src_bytes,
        capture_output=True,
        check=True,
    )
    dest_gz.write_bytes(p_gz.stdout)


def split_pages(file_path: Path, dest_dir: Path) -> int:
    data = file_path.read_bytes()
    if len(data) % PAGE_SIZE != 0:
        raise SystemExit(
            f"sqlite_pages source must be a multiple of {PAGE_SIZE}; "
            f"{file_path} is {len(data)} bytes"
        )
    count = 0
    for offset in range(0, len(data), PAGE_SIZE):
        page = data[offset:offset + PAGE_SIZE]
        zst = dest_dir / f"{offset}.zst"
        gz = dest_dir / f"{offset}.gz"
        compress_pair(page, zst, gz)
        count += 1
    return count


def whole_file(src: Path, dest_no_ext: Path) -> None:
    data = src.read_bytes()
    compress_pair(data, dest_no_ext.with_name(dest_no_ext.name + ".zst"),
                  dest_no_ext.with_name(dest_no_ext.name + ".gz"))


def main() -> int:
    if not SOURCE.is_dir():
        raise SystemExit(f"missing source dir: {SOURCE}")
    if SERVED_FILES.exists():
        # idempotent regeneration
        shutil.rmtree(SERVED_FILES)
    SERVED_FILES.mkdir(parents=True, exist_ok=True)

    # main.sqlite3 → per-page chunks
    pages_dir = SERVED_FILES / "pocketdb" / "main.sqlite3" / "pages"
    n_pages = split_pages(SOURCE / "pocketdb" / "main.sqlite3", pages_dir)
    print(f"wrote {n_pages} page chunks (.zst + .gz) under {pages_dir.relative_to(ROOT)}")

    # blocks/000000.dat → whole-file chunk
    blocks_dest = SERVED_FILES / "blocks" / "000000.dat"
    whole_file(SOURCE / "blocks" / "000000.dat", blocks_dest)
    print(f"wrote whole-file chunk (.zst + .gz) at {blocks_dest.relative_to(ROOT)}.[zst|gz]")

    # chainstate/CURRENT → whole-file chunk
    cs_dest = SERVED_FILES / "chainstate" / "CURRENT"
    whole_file(SOURCE / "chainstate" / "CURRENT", cs_dest)
    print(f"wrote whole-file chunk (.zst + .gz) at {cs_dest.relative_to(ROOT)}.[zst|gz]")

    return 0


if __name__ == "__main__":
    sys.exit(main())
