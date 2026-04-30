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
    summary: Initial harness README enumerating tool prerequisites and run patterns
    changes:
      - "Document tool prerequisites with pinned-or-tested versions"
      - "Document local venv setup for check-jsonschema"
      - "Document the run patterns the verification scripts share"
---

# Chunk 001 Verification Harness

This directory holds the verification scripts and stub server that exercise the
Chunk 001 contract artifacts (`../contracts/`) against a conforming canonical
(synthetic fixture under `../fixtures/`, or a real one published by `delt.3`).

The harness is the test surface for this chunk — running it green against a
conforming canonical IS the gate evidence (T051, T052).

## Tool prerequisites

All scripts assume POSIX shell semantics (`/bin/bash`). Versions below are the
pinned-or-tested versions on the machine that authored these artifacts; later
patch versions are expected to work.

| Tool | Tested version | Source |
|---|---|---|
| `bash` | 5.x | host shell |
| `curl` | 8.5.0 | apt `curl` |
| `jq` | 1.7.x | apt `jq` |
| `sha256sum` | 9.4 (GNU coreutils) | apt `coreutils` |
| `zstd` | 1.5.5+ | apt `zstd` |
| `gzip` | 1.12 | apt `gzip` |
| `python3` | 3.10+ (tested 3.12.3) | apt `python3` |
| `check-jsonschema` | 0.37.x | local venv (see below) |

`check-jsonschema` is installed into a project-local virtualenv so that no
system Python packages are touched.

## Local venv setup (one-time)

```bash
python3 -m venv harness/.venv
harness/.venv/bin/pip install --quiet check-jsonschema
```

The verification scripts call `harness/.venv/bin/check-jsonschema` directly
(absolute path inside the feature directory) so no shell activation is needed.

If you prefer a system-wide install, any `check-jsonschema >= 0.27` works; edit
the scripts to call `check-jsonschema` from `$PATH` instead.

## Run patterns

All scripts in this directory follow these conventions:

- Exit `0` on success (predicate satisfied), non-zero on failure.
- Emit a single human-readable summary line on success (e.g.,
  `schema OK`, `trust-root MATCH`, `freshness OK`).
- Emit a structured `<predicate> VIOLATION: <reason>` line on failure.
- Take all inputs as positional arguments — no environment-variable contracts.
- Read no global state beyond the arguments and the files they reference.

The scripts are designed to be re-run idempotently against a fixed fixture or
against a live canonical (just substitute a real `<base>` URL).

## Stub server

`stub-server.py` serves any `fixtures/canonical/served/` tree as a chunk store
honoring the contract in `../contracts/http-encoding.md`. It is the in-repo
moral equivalent of the production publisher — sufficient for the harness to
exercise the encoding-negotiation, trust-root, and chunk-hash predicates
end-to-end without real-server dependence.

```bash
python3 harness/stub-server.py fixtures/canonical/served/
# Serves on http://127.0.0.1:8080/ by default
```

The server expects pre-compressed `<chunk>.zst` and `<chunk>.gz` siblings for
each chunk URL; it does NOT compress on the fly. This mirrors the publisher
contract (D8 in `../plan.md`).

## Out-of-scope

- Load testing (BC-003) — owned by `delt.3` deployment.
- Real-canonical drill verification (US-6) — invoked at `delt.3` deployment
  time using `verify-drill-canonical.sh` against the live publisher; in-repo
  evidence uses the synthetic fixture as a stand-in.
- Code coverage / unit testing — there is no production source code in this
  chunk. The harness IS the test suite.
