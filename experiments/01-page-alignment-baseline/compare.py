#!/usr/bin/env python3
import os
import sys
import time
import mmap

OLD = sys.argv[1]
NEW = sys.argv[2]
BASE = 4096
GRANULARITIES = [4096, 32768, 65536, 131072, 262144, 1048576]

old_size = os.path.getsize(OLD)
new_size = os.path.getsize(NEW)
common = min(old_size, new_size)
n_base = common // BASE

print("OLD: %s (%d bytes)" % (OLD, old_size), flush=True)
print("NEW: %s (%d bytes)" % (NEW, new_size), flush=True)
print("Common: %d bytes = %d blocks of %d bytes" % (common, n_base, BASE), flush=True)
print("Extra bytes in NEW (must be downloaded regardless): %d" % (new_size - common), flush=True)
print("Granularities: %s" % GRANULARITIES, flush=True)
print("", flush=True)

t0 = time.time()
matches = bytearray(n_base)

with open(OLD, "rb") as of_, open(NEW, "rb") as nf_:
    om = mmap.mmap(of_.fileno(), common, prot=mmap.PROT_READ)
    nm = mmap.mmap(nf_.fileno(), common, prot=mmap.PROT_READ)
    om.madvise(mmap.MADV_SEQUENTIAL)
    nm.madvise(mmap.MADV_SEQUENTIAL)
    omv = memoryview(om)
    nmv = memoryview(nm)

    last_report = t0
    report_every = 5
    for i in range(n_base):
        o = i * BASE
        if omv[o:o+BASE] == nmv[o:o+BASE]:
            matches[i] = 1
        if i % 100000 == 0:
            now = time.time()
            if now - last_report >= report_every:
                pct = 100.0 * i / n_base
                rate_mb = (i * BASE) / (now - t0) / 1024 / 1024 if (now - t0) > 0 else 0
                eta_s = (n_base - i) * BASE / (rate_mb * 1024 * 1024) if rate_mb > 0 else 0
                print("[%ds] %.1f%% scanned, %.0f MB/s, ETA %ds" % (int(now-t0), pct, rate_mb, int(eta_s)), flush=True)
                last_report = now

    omv.release()
    nmv.release()
    om.close()
    nm.close()

scan_elapsed = time.time() - t0
print("", flush=True)
print("Scan complete in %.1fs" % scan_elapsed, flush=True)
print("", flush=True)

print("%10s %14s %14s %8s %16s %12s" % ("Block", "Total", "Matched", "Reuse", "BytesNeed", "NeedMB"))
print("-" * 80, flush=True)
for g in GRANULARITIES:
    factor = g // BASE
    n_groups = n_base // factor
    matched_groups = 0
    for gi in range(n_groups):
        ok = True
        s = gi * factor
        for j in range(factor):
            if matches[s + j] == 0:
                ok = False
                break
        if ok:
            matched_groups += 1
    reuse_pct = 100.0 * matched_groups / n_groups if n_groups else 0
    bytes_needed = (n_groups - matched_groups) * g + (new_size - common)
    print("%10d %14d %14d %7.2f%% %16d %11.0fMB" % (g, n_groups, matched_groups, reuse_pct, bytes_needed, bytes_needed/1024/1024), flush=True)

print("", flush=True)
print("Reference: full file size = %d bytes (%.1f GB)" % (new_size, new_size/1024/1024/1024), flush=True)
