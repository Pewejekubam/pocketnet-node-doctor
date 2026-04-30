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
    summary: Outbound Gate 001-Schema → 002 (Manifest schema frozen) evidence bundle (T051)
    changes:
      - "Reference contracts/manifest.schema.json as the frozen schema artifact"
      - "Aggregate the four foundational schema-validation evidence logs"
---

# Outbound Gate 001-Schema → 002 — Manifest Schema Frozen

This bundle is the evidence the chunking-doc Gate 001-Schema → 002 requires
before any downstream chunk (002 diagnose, 003 apply, 004 drill) may consume
the manifest schema. The frozen artifact is `../contracts/manifest.schema.json`;
the predicates below verify it satisfies CSC001-001 and the structural
invariants the downstream chunks will rely on.

## Frozen artifact

- **Path:** `specs/002-001-delta-recovery-client-chunk-001/contracts/manifest.schema.json`
- **`$schema`:** `https://json-schema.org/draft/2020-12/schema`
- **`$id`:** `manifest.schema.v1.json`
- **`format_version` constant:** `1`

## Evidence

### (a) Schema validates against the JSON Schema Draft 2020-12 meta-schema

`harness/.venv/bin/check-jsonschema --check-metaschema contracts/manifest.schema.json`

Captured in `schema-meta-validation.log`:

```
ok -- validation done
```

### (b) `$comment` cites the canonical-form serialization rule and trust-root construction (CSC001-001(b))

Captured in `schema-comment-citation.log` — the schema's top-level `$comment`
contains the literal substrings:

- "sorted JSON keys"
- "no insignificant whitespace"
- "UTF-8"
- "trust-root"
- "SHA-256"
- "canonical_form_serialize"

### (c) Top-level required fields enumerated (CSC001-001(a))

Captured in `schema-required-fields.log` — the schema's top-level `required`
array equals exactly `["format_version", "canonical_identity", "entries",
"trust_anchors"]`.

### (d) `change_counter` ↔ `pocketdb/main.sqlite3` conditional wired (CR001-007)

Captured in `schema-change-counter-conditional.log` — the
`sqlite_pages_entry.allOf[0]` block's `if/then/else` clause:

- `if path == "pocketdb/main.sqlite3"` ⇒ `then required: [change_counter]`
- otherwise ⇒ `else not.required: [change_counter]`

### (e) Path grammar consistency between schema and chunk-url-grammar (CR001-004)

Captured in `path-grammar-consistency.log` — the schema's
`path` regex and `contracts/chunk-url-grammar.md`'s prohibitions agree on:

- leading `/` is rejected
- `..` segments are rejected
- only `[A-Za-z0-9_.-]` component characters are accepted

Concrete sample table is in the log.

### (f) Trust-root sidecar shape consistency (CR001-006)

Captured in `trust-root-shape-consistency.log` — `contracts/trust-root-format.md`
and `data-model.md` agree on:

- Body is exactly 65 bytes
- 64 lowercase hex characters + single LF (`0x0A`)
- No JSON wrapper, no `\r\n`, no surrounding whitespace

## Gate verdict

PASS — the schema is frozen, self-consistent against its claims, consistent
with the chunk-url grammar and the trust-root sidecar contract, and
expressible as a JSON Schema Draft 2020-12 document. Downstream chunks may
consume `contracts/manifest.schema.json` as the stable contract surface.
