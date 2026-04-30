You are running `/speckit.superb.finish` for Chunk ${CHUNK_ID} (${CHUNK_NAME}).

## Context

- Feature dir: ${FEATURE_DIR}
- Feature branch: ${BRANCH}
- Verify gate passed: spec status = Verified
- Chunking doc (Progress Tracker + Session Breadcrumbs): ${CHUNKING_DOC_PATH}

## Task

Run `/speckit.superb.finish`. The command presents options; the autonomous default for 039 chunks is **option 1 — merge locally**:

### Option 1 (default): merge locally

```bash
git checkout main
git pull origin main
git merge --no-ff ${BRANCH} -m "Merge Chunk ${CHUNK_ID}: ${CHUNK_NAME} into main — <outbound gate status>"
git push origin main
git branch -d ${BRANCH}
git push origin --delete ${BRANCH}
```

The `--no-ff` merge is REQUIRED (preserves chunk identity as a merge commit for retrospective grouping).

## Pre-merge checks

Before running the merge sequence:

1. Working tree on `${BRANCH}` must be clean: `git status` returns nothing
2. `git rev-parse ${BRANCH}` must match `HEAD`
3. `git log main..${BRANCH} --oneline` must show the chunk's phase commits
4. The verify-gate evidence must still be fresh (don't re-verify here — it was verified in the prior stage)

## Post-merge verification

After merging:

1. `git log main -1 --format='%H %s'` must show the `Merge Chunk ${CHUNK_ID}: …` commit
2. Re-run a minimal smoke test on main to confirm the merge didn't corrupt state:
   - For chunks with test suites: run the whole suite on main; expect N = (prior main tests) + (new chunk tests) = all passing
   - For chunks with infra: re-verify the service is healthy post-merge

## Chunking doc update

Update `${CHUNKING_DOC_PATH}`:
1. Bump the `version:` in frontmatter (patch = within-chunk, minor = chunk merged, major = new capability landed)
2. Add a `changelog:` entry at the top listing the merge details
3. Update the chunk's Session Breadcrumb block with `Last session` + `Speckit stage = finish (complete)` + merge commit hash + `Next action = chunk complete — <next chunk> ready`
4. Update the downstream chunk's Session Breadcrumb to flip blockers

Commit the chunking-doc update as a separate commit:
```
docs(NNN): Chunk ${CHUNK_ID} merged — <gate transition>; chunking doc <old>→<new>
```

## Chunking-doc discipline

Update the chunking doc's Progress Tracker row for Chunk ${CHUNK_ID}: flip Status `pending` → `merged`, add the merge commit hash + date to the Gate column. Update the Session Breadcrumb block (if present) to `Speckit stage = finish (complete)` + `Next action = chunk complete — <next chunk> ready`.

If the project has an epic-tracking bead (per MEMORY.md feedback_epic_bead_on_chunk_merge), append a merge note:

```bash
bd update <epic-bead> --append-notes "Chunk ${CHUNK_ID} (${SPEC_SLUG}) merged <date> → merge commit <hash>; outbound gate <from>→<to> status = <closed|open>"
```

The epic-bead ID is project-specific — read it from the chunking doc's frontmatter (`bead:` field) or the Progress Tracker caption if declared; omit this step if no epic bead exists for the spec.

## Halt conditions

- Working tree on feature branch is not clean: STOP with halt_reason="uncommitted changes on ${BRANCH}"
- `main` has advanced since the chunk branched: STOP with halt_reason="main advanced since chunk branched — requires rebase-and-re-verify before merge"
- Post-merge smoke test fails: STOP with halt_reason="post-merge regression: <test-name>"
- Chunking-doc `version` bump conflicts with another pending change: STOP with halt_reason="chunking doc version conflict"

## Return contract

The runner parses the JSON between the === tags via `jq`. Values must be JSON-valid.

```
=== CHUNK-RUNNER RETURN ===
{
  "stage": "superb_finish",
  "status": "pass",
  "merge_commit": "<sha>",
  "branch_deleted": true,
  "chunking_doc_version_old": "<x.y.z>",
  "chunking_doc_version_new": "<x.y.z>",
  "epic_bead_noted": true,
  "post_merge_test_count": 0,
  "post_merge_passing": 0,
  "post_merge_failing": 0,
  "halt_reason": "",
  "next_stage_inputs": "<pointer to next chunk, e.g. 'Chunk 002 ready' or 'Epic complete'>"
}
=== END ===
```
