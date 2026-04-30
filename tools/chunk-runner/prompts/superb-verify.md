You are running `/speckit.superb.verify` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Implementation complete: all tasks.md tasks green
- Outbound gate SCs declared in: chunking doc ${CHUNKING_DOC_PATH} § Chunk ${CHUNK_ID} (§ Success Criteria + § Post-Implementation Verification)

## Task

Run `/speckit.superb.verify`. This is the **completion gate** — no chunk may merge without it. It produces:
1. Spec-coverage checklist: every FR + SC mapped to concrete test evidence
2. Fresh full-suite test run (credential-loaded mode)
3. Bare-shell I-4 boundary proof (credential-absence failures cite the expected denial path)
4. Infrastructure health confirmation (if chunk touches store/tunnel/container)

## Required evidence pair (038-ported)

The gate requires BOTH runs:

### 1. Credential-loaded suite

```bash
# Load credentials
source <appropriate env file>

# Run full suite
<test-runner> # e.g. `npm test -- --test-reporter=spec`
```

Expected: **all tests pass**. Any failure = gate fail.

### 2. Bare-shell I-4 boundary proof

```bash
# Start a fresh shell with NO credentials loaded
bash -c 'unset PAM_SUBSTRATE_PG_PASSWORD ZOHO_REFRESH_TOKEN … ; <test-runner>'
```

Expected: **credential-dependent tests fail with explicit credential-absence errors** (not silent exits, not timeouts — named "must be set" or equivalent). This is the autonomy-denial boundary proof — I-4 from the 038 substrate chunks.

Tests that do NOT depend on external credentials MUST still pass in this run. Any unexpected failure = gate fail.

## Spec-coverage checklist

For each FR in spec.md:
- [x] FR-<id> → test `<test file>:<test name>` (one or more)

For each SC in spec.md:
- [x] SC-<id> → test `<test file>:<test name>` (one or more)

Any FR or SC without a mapped test = gate fail with halt_reason="spec-coverage gap on <id>".

## Infrastructure checks (when applicable)

If the chunk touches a service or infra component, verify it's healthy after implementation:
- Postgres container: `docker exec pam-substrate-postgres psql -c 'SELECT 1'`
- SSH tunnel: `systemctl is-active pam-substrate-tunnel.service`
- Bind: `ss -tlnp | grep 127.0.0.1:5432`
- Table presence: appropriate `\d+ <table>` checks

Record every health check result in the verify output.

## Halt conditions

- Any test failure in credential-loaded suite → halt
- Credential-loaded test fails AND its name doesn't appear in "known-flaky" list (there is no such list for 039 yet) → halt
- Bare-shell boundary proof: a test that should fail (credential-dependent) PASSES or SILENTLY-SKIPS → halt with halt_reason="autonomy-denial boundary violated on <test>"
- Any FR or SC unmapped to a test → halt with halt_reason="spec-coverage gap on <id>"
- Infrastructure check fails → halt with halt_reason="infra regression: <component>"

## When done

Flip spec status to `Verified`. Commit the final evidence bundle on the feature branch. The runner handles JSONL stage_completed + post-flight sc_verified events and the retro bead — do not write beads from within this prompt.

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "superb_verify",
  "status": "pass",
  "credential_loaded_test_count": 0,
  "credential_loaded_passing": 0,
  "credential_loaded_failing": 0,
  "bare_shell_expected_failures": 0,
  "bare_shell_unexpected": 0,
  "spec_coverage_total_frs": 0,
  "spec_coverage_total_scs": 0,
  "spec_coverage_gaps": 0,
  "infra_checks_passed": 0,
  "infra_checks_failed": 0,
  "halt_reason": "",
  "next_stage_inputs": "<evidence summary for superb.finish>"
}
=== END ===
```
