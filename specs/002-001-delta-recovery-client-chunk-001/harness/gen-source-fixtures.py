#!/usr/bin/env python3
"""
gen-source-fixtures.py — generate the synthetic-canonical source bytes (T012-T014).

Produces three files under fixtures/canonical/source/ that together form a
small but contract-realistic canonical:

  pocketdb/main.sqlite3   — 4 pages × 4096 bytes = 16384 bytes, valid SQLite
                            header carrying a chosen change_counter
  blocks/000000.dat       — small opaque file
  chainstate/CURRENT      — small opaque file

The bytes are deterministic (seeded RNG) so re-running the script produces
byte-identical fixtures and therefore byte-identical hashes — important for
gate-evidence reproducibility.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

PAGE_SIZE = 4096
NUM_PAGES = 4
CHANGE_COUNTER = 314159  # the value the SQLite header will carry

ROOT = Path(__file__).resolve().parent.parent / "fixtures" / "canonical" / "source"


def deterministic_bytes(seed: int, n: int) -> bytes:
    # Linear-congruential filler. We don't need crypto-grade randomness —
    # we just need byte streams that aren't all-zero (which would defeat
    # zstd/gzip exercise) and are reproducible across runs.
    state = seed & 0xFFFFFFFF
    out = bytearray(n)
    for i in range(n):
        state = (1103515245 * state + 12345) & 0xFFFFFFFF
        out[i] = (state >> 16) & 0xFF
    return bytes(out)


def build_sqlite_main(change_counter: int) -> bytes:
    # SQLite database header is 100 bytes (file format § 1.3).
    # We construct a minimally-valid header carrying our chosen change_counter
    # at offset 24 (4-byte big-endian, the "file change counter"). The rest of
    # the file is deterministic filler — the doctor never parses our synthetic
    # SQLite content; it only hashes pages and reads the change_counter via the
    # header offset.
    header = bytearray(100)
    header[0:16] = b"SQLite format 3\x00"
    struct.pack_into(">H", header, 16, PAGE_SIZE)  # page size
    header[18] = 1  # file format write version
    header[19] = 1  # file format read version
    header[20] = 0  # reserved bytes per page
    header[21] = 64  # max payload fraction (SQLite constant)
    header[22] = 32  # min payload fraction
    header[23] = 32  # leaf payload fraction
    struct.pack_into(">I", header, 24, change_counter)  # change_counter
    struct.pack_into(">I", header, 28, NUM_PAGES)       # in-header database size
    # offset 32-35: first freelist page (0 — none)
    # offset 36-39: total freelist pages (0)
    struct.pack_into(">I", header, 40, 0)  # schema cookie
    struct.pack_into(">I", header, 44, 1)  # schema format number (1=valid)
    struct.pack_into(">I", header, 48, 20000)  # default page cache size
    struct.pack_into(">I", header, 56, 1)  # text encoding (1=UTF-8)
    struct.pack_into(">I", header, 60, 0)  # user version
    struct.pack_into(">I", header, 64, 0)  # incremental vacuum mode
    struct.pack_into(">I", header, 68, 0)  # application id
    # offset 72-91: reserved, zeroed
    struct.pack_into(">I", header, 92, change_counter)  # version-valid-for
    struct.pack_into(">I", header, 96, 3043000)         # SQLite version number

    # Page 0 = header + filler to PAGE_SIZE bytes
    page0 = bytes(header) + deterministic_bytes(seed=0, n=PAGE_SIZE - len(header))
    pages = [page0]
    for i in range(1, NUM_PAGES):
        pages.append(deterministic_bytes(seed=i, n=PAGE_SIZE))
    body = b"".join(pages)
    assert len(body) == PAGE_SIZE * NUM_PAGES
    return body


def main() -> int:
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "pocketdb").mkdir(parents=True, exist_ok=True)
    (ROOT / "blocks").mkdir(parents=True, exist_ok=True)
    (ROOT / "chainstate").mkdir(parents=True, exist_ok=True)

    main_sqlite = ROOT / "pocketdb" / "main.sqlite3"
    main_sqlite.write_bytes(build_sqlite_main(CHANGE_COUNTER))

    # Sized to be larger than one page but not artificially huge — the
    # whole-file hash is the property under test, not the size.
    (ROOT / "blocks" / "000000.dat").write_bytes(
        deterministic_bytes(seed=999, n=8192)
    )
    (ROOT / "chainstate" / "CURRENT").write_bytes(
        deterministic_bytes(seed=42, n=512)
    )

    for p in [
        ROOT / "pocketdb" / "main.sqlite3",
        ROOT / "blocks" / "000000.dat",
        ROOT / "chainstate" / "CURRENT",
    ]:
        print(f"wrote {p.relative_to(ROOT.parent.parent.parent)} ({p.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
