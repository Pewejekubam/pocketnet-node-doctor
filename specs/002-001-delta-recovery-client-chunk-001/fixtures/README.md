---
version: 0.1.0
status: draft
created: 2026-04-30
last_modified: 2026-04-30
authors: [pewejekubam, claude]
related: ../tasks.md
changelog:
  - version: 0.1.0
    date: 2026-04-30
    summary: Initial fixtures README — drill-canonical pinning procedure for sibling delt.3
    changes:
      - "Document fixture layout (canonical/source, canonical/served, negative/)"
      - "Document the drill-canonical pinning procedure for sibling delt.3 (T047)"
      - "Document how harness/verify-drill-canonical.sh is run at delt.3 deployment time"
---

# Chunk 001 Fixtures

The fixtures here back the verification harness in `../harness/`. They are
synthetic — small, deterministic, and reproducible — so the harness can run
green end-to-end inside this repo without depending on a live publisher. The
real drill canonical is published by the sibling `pocketnet_create_checkpoint`
repo (`delt.3`); this directory's fixture is the stand-in proving the contract
predicates are exercisable.

## Layout

```
fixtures/
├── canonical/
│   ├── source/          # raw byte sources, written by harness/gen-source-fixtures.py
│   │   ├── pocketdb/main.sqlite3      (16384 bytes, 4 pages, valid SQLite header)
│   │   ├── blocks/000000.dat          (8192 bytes, deterministic filler)
│   │   └── chainstate/CURRENT         (512 bytes, deterministic filler)
│   └── served/          # what a publisher would serve; written by gen-served-{manifest,chunks}.py
│       ├── manifest.json              (canonical-form, sorted keys, no insig. whitespace, no trailing LF)
│       ├── trust-root.sha256          (65 bytes: 64 hex + LF)
│       └── files/...                  (per-chunk .zst + .gz pre-compressed variants)
└── negative/            # variants that the harness verifies are REJECTED
    ├── manifest-tampered.json         (T027 — change_counter mutated)
    ├── cc-on-other-sqlite.json        (T031 — change_counter on a non-main entry)
    ├── cc-missing-on-main.json        (T032 — change_counter absent from main entry)
    └── manifest-stale.json            (T042 — created_at 60 days old)
```

## Regenerating from source

The source bytes are written by deterministic generators so re-running the
generators yields byte-identical fixtures and therefore byte-identical hashes.

```bash
python3 harness/gen-source-fixtures.py     # T012-T014
python3 harness/gen-served-manifest.py     # T018 (default created_at = now - 7 days)
python3 harness/gen-served-chunks.py       # T020-T021
COMPUTED=$(jq -cS . fixtures/canonical/served/manifest.json | tr -d '\n' | sha256sum | awk '{print $1}')
printf '%s\n' "$COMPUTED" > fixtures/canonical/served/trust-root.sha256   # T019
```

The freshness fixture (manifest-stale.json) and the tampered fixture
(manifest-tampered.json) are derived from the served manifest — see the
relevant tasks in `../tasks.md`.

## Drill-canonical pinning procedure (delt.3 hand-off)

US-6 / CSC001-003 require that a real canonical published by this chunk is
pinned as the **drill canonical** for Chunk 004 (the doctor's diagnose-then-
apply integration drill). The pinning procedure has two endpoints:

1. **Server side (`delt.3`):** When `delt.3` cuts the canonical that will back
   the drill rig, it records the canonical's `block_height` and SHA-256 of the
   canonical-form manifest payload (the trust-root) in a place the drill-rig
   build can read. Concretely: the drill-rig doctor build (Chunk 004's CI job)
   compiles in this trust-root via the One-Time Setup Checklist mechanism
   (pre-spec Implementation Context). The canonical's manifest URL stays
   accessible at least until the next higher-block-height canonical is
   published (spec Q4/A4 conservative interpretation; concretized to a longer
   retention by `delt.3` operationally).

2. **Drill-time verification (this harness):** At Chunk 004's drill-evaluation
   time, run

   ```bash
   harness/verify-drill-canonical.sh <base> <drill-height> <expected-trust-root-hex>
   ```

   against `delt.3`'s deployed canonical. The script:

   - Fetches `<base>/canonicals/<drill-height>/manifest.json` and
     `<base>/canonicals/<drill-height>/trust-root.sha256`.
   - Re-serializes the manifest in canonical form, hashes it, and asserts the
     hash equals the published sidecar (internal consistency).
   - Asserts the published sidecar value equals `<expected-trust-root-hex>`
     (the value the drill rig's doctor build was built to trust).

   If both assertions pass, the drill canonical is the canonical the drill
   rig's compiled-in pin trusts — the precondition Chunk 004 needs.

## In-repo stand-in (T048)

In this repo, US-6 is verified at the harness level using the synthetic
fixture as a stand-in for the real drill canonical. The fixture's
`block_height` and the trust-root that hashing produces play the part of
`<drill-height>` and `<expected-trust-root-hex>`. The captured pass log lives
at `../evidence/us6-drill-canonical-stub-pass.log`.

The real-canonical predicate is `delt.3`'s deployment-time concern, run with
the same script against `delt.3`'s live publisher.
