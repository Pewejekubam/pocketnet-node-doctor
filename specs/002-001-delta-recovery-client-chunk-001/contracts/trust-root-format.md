# Contract: Trust-Root Sidecar Format

**Branch**: `002-001-delta-recovery-client-chunk-001` | **Date**: 2026-04-30 | **Plan**: [../plan.md](../plan.md)

## Purpose

Defines the on-wire shape of the trust-root SHA-256 published alongside each manifest. Doctor binaries are built against the trust-root constant for a chosen canonical (the One-Time Setup Checklist; pre-spec). This contract pins the artifact shape that workflow consumes.

## URL

`<base>/canonicals/<block_height>/trust-root.sha256` — see [chunk-url-grammar.md](chunk-url-grammar.md).

## On-wire shape

The response body is a **plain-text** file with this exact byte structure:

```
[64 lowercase hex chars][LF (0x0A)]
```

- Total body length: **65 bytes**.
- Hex chars: `0–9`, `a–f`. Uppercase is invalid. No `0x` prefix. No surrounding whitespace, no quotes, no JSON wrapper.
- Trailing single `\n`. No `\r\n`. No multiple newlines.

## HTTP response shape

| Header | Value |
|---|---|
| `Content-Type` | `text/plain; charset=utf-8` |
| `Content-Length` | `65` (or `Content-Encoding`-adjusted; see encoding note below) |

### Encoding note

The trust-root sidecar is small enough that pre-compression is not load-bearing. The publisher MAY serve the sidecar without `Content-Encoding` regardless of the request's `Accept-Encoding`; the encoding-negotiation contract in [http-encoding.md](http-encoding.md) is binding for **chunk URLs**, not for this 65-byte sidecar or for the manifest JSON. (Out-of-band consumers using `curl` to verify the trust-root expect identity-encoding plain text; servers SHOULD NOT 406 a sidecar request that lacks zstd/gzip in `Accept-Encoding`.)

## Construction

```
trust_root_hex = lowercase_hex( SHA-256( canonical_form_serialize(manifest_json) ) )
sidecar_body  = trust_root_hex + "\n"
```

`canonical_form_serialize` is per pre-spec Implementation Context: sorted JSON keys at every nesting level, no insignificant whitespace, UTF-8.

## Verification

A doctor binary or out-of-band consumer verifies as:

```
fetched_manifest = GET <manifest-url>
fetched_sidecar  = GET <trust-root-url>
expected_hex     = read first 64 chars of fetched_sidecar
computed_hex     = lowercase_hex( SHA-256( canonical_form_serialize(parse_json(fetched_manifest)) ) )
assert computed_hex == expected_hex
```

Out-of-band, with a manifest that is already in canonical form on the wire (a property the publisher SHOULD ensure):

```bash
curl -sS <manifest-url> | tr -d '\n' | sha256sum | awk '{print $1}'   # computed_hex
curl -sS <trust-root-url> | head -c 64                                # expected_hex
```

(If the served manifest is not byte-identical to its canonical-form serialization — e.g., a pretty-printed mirror — the consumer must re-serialize before hashing. The publisher SHOULD serve the canonical-form bytes directly so the simpler `curl | sha256sum` workflow is viable; but the doctor binary always re-serializes defensively.)

## Invariants

- Trust-root is **external** to the manifest. The manifest does not contain its own trust-root field. (Avoids the meta-hash recursion problem.)
- For one canonical at one block height, there is **exactly one** trust-root value. Two manifests at the same block height with different canonical-form bytes are two different canonicals (a publisher error or a tampered mirror).
- For a doctor binary built with pinned trust-root `T`, exactly one published manifest hashes to `T` (BC-001).
- Two doctor binaries pinning the same `T`, fetching the same manifest URL, accept the same canonical (BC-002).

## Acceptance mapping

| Spec acceptance | Verified by |
|---|---|
| US-1 AS-1 (`SHA-256(canonical-form payload) == T`) | construction + verification recipe above |
| US-2 AS-1 (two builds, same `T`, identical canonical_identity) | invariant: one trust-root → one manifest |
| US-2 AS-2 (manifest with different canonical-form-hash → doctor refuses) | invariant: canonical-form-hash != T → reject |
| CR001-006 (SHA-256 of canonical-form payload published alongside manifest) | sidecar URL + on-wire shape |
| CSC001-002(a) (`sha256sum` of manifest body equals trust-root) | verification recipe |
