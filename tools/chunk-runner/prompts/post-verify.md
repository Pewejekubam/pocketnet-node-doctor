You are running `post_verify` for Chunk ${CHUNK_ID} (${CHUNK_NAME}) of spec `${SPEC_SLUG}`.

This stage runs after `superb_verify` has passed. It maintains the chunking document
to reflect that this chunk's gate criteria are met: ticks the outbound gate checkboxes
and bumps the frontmatter version (PATCH). The stage is idempotent — safe to --rerun.

## Context

- Chunking doc: `${CHUNKING_DOC_PATH}`
- Feature dir: `${FEATURE_DIR}`
- Chunk ID: `${CHUNK_ID}`
- Chunk name: `${CHUNK_NAME}`
- Spec slug: `${SPEC_SLUG}`
- Run ID: `${RUN_ID}`

## Tasks (execute in order)

### 1. Idempotency check

Read `${CHUNKING_DOC_PATH}` from the repo root.

Find the `## Chunk ${CHUNK_ID}:` section — the block from that heading up to the next
`## ` heading (or end of file). All edits in this stage are **scoped exclusively to
this section**.

Within that section, look for a `### Infrastructure Gate` subsection. This is the
outbound gate for Chunk ${CHUNK_ID}. **Do NOT look at gates in other chunks' sections.**

If there is **no `### Infrastructure Gate` subsection** within Chunk ${CHUNK_ID}'s
section, return pass immediately with `"no_gate_found": true`. No further action.

If ALL checkboxes in the gate subsection are already `- [x]` (ticked), this stage has
already run. Return pass with `"already_complete": true`. Do NOT make any changes.

### 2. Tick the outbound gate checkboxes

Within Chunk ${CHUNK_ID}'s `### Infrastructure Gate` subsection only:
change every `- [ ]` to `- [x]`.

**Do NOT touch:**
- Gate sections in any other chunk's section
- `## Per-Chunk Addenda` or `### Chunk X Specific` checklist items
- `## One-Time Setup Checklist` items
- Any `### Post-Merge Integrity` or convergence-check items

Count the number of checkboxes you tick. Record this as `checkboxes_ticked`.

### 3. Bump the frontmatter version (PATCH)

The chunking doc YAML frontmatter has `version:` and `changelog:` fields.

- Read the current `version:` (semver, e.g. `0.2.0`)
- Apply a **PATCH** bump: last digit +1 (e.g. `0.2.0` → `0.2.1`)
- Record the old and new version as `version_before` and `version_after`
- Prepend a new entry at the **top** of the `changelog:` list:
  ```yaml
  - version: <new-version>
    date: <today-YYYY-MM-DD>
    summary: "chunk-runner post-verify: Chunk ${CHUNK_ID} outbound gate ticked after superb_verify pass"
    changes:
      - "Chunk ${CHUNK_ID} Infrastructure Gate checkboxes ticked (<N> items)"
  ```
- Update the `version:` field in frontmatter to the new version
- Update the `last_modified:` field in frontmatter to today's date

Use `date +%Y-%m-%d` to get today's date.

### 4. Commit the changes

```bash
git add ${CHUNKING_DOC_PATH}
git commit -m "docs(${SPEC_SLUG}/chunk-${CHUNK_ID}): tick outbound gate + PATCH version bump after post-verify"
```

Verify the working tree is clean after the commit with `git status`.

## Rules

- PATCH bump only — this is gate maintenance, not a scope change
- Only modify Chunk ${CHUNK_ID}'s outbound Infrastructure Gate section
- Commit must land on the current feature branch (you should already be on it — verify
  with `git branch --show-current` if unsure)
- Do NOT write beads — the runner handles all bead writes
- Do NOT run `git push` — the runner handles the push

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid:
strings quoted, numbers unquoted, no trailing commas.

Example (do NOT copy this — emit your actual values):

=== CHUNK-RUNNER RETURN ===
{
  "stage": "post_verify",
  "status": "pass",
  "already_complete": false,
  "no_gate_found": false,
  "checkboxes_ticked": 0,
  "version_before": "",
  "version_after": "",
  "artifacts_touched": "${CHUNKING_DOC_PATH}",
  "halt_reason": "",
  "next_stage_inputs": "Gate checkboxes ticked; chunking doc updated"
}
=== END ===

Emit your actual return block (with real values) at the end of your response.
`"status"` must be `"pass"` on success, `"halt"` on failure. Any non-pass status
requires a non-empty `"halt_reason"`.
