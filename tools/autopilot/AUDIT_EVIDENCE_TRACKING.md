# Audit: Evidence Tracking in Git History (last 50 commits)

## Summary
Tracked evidence bundles were committed in past commits. All have been untracked in the current working tree.

## Findings
- Commit 4a7989fc577249eecebe1fb87a63a2d879ccaeeb
  - Path(s): local-ci/verification/autopilot_release/LATEST/*
  - Files: SHA256SUMS.txt, inventory/git_branch.txt, git_commit_after.txt, git_commit_before.txt, git_status_after.txt, git_status_before.txt, run_timestamp.txt, tracked_files_snapshot.txt, reports/AUTOPILOT_FINAL_REPORT.md
- Commit 2a77ac397d4429a0815b9a84d0c4ebd3cf3cf049
  - Path(s): local-ci/verification/final_release/LATEST/*; local-ci/verification/reality_map/LATEST/*
  - Files: SHA256SUMS.txt, ci/deploy.yml, inventory/git_branch.txt, git_commit.txt, git_status.txt, run_timestamp.txt, tracked_files.txt, reports/FINAL_REPORT.md, PROOF_INDEX.md, REALITY_MAP.md, extract/components.json, extract/evidence.json
- Commit bdd56c366fd9a5407d0aa24777f1dd995d6d2007
  - Path(s): local-ci/verification/stabilize_pack/LATEST/*
  - Files: PROOF_INDEX.md, SHA256SUMS.txt, anchors/ANCHORS.json, artifacts/git_files_before.txt, ci/workflow_summary.md, inventory/git_commit_after.txt, git_commit_before.txt, git_status_after.txt, git_status_before.txt, run_timestamp.txt, reports/STABILIZE_REPORT.md, tests/firebase-functions_test.log, tests/rest-api_test.log
- Commit 3ab6e7bf515aa8af7bff6d042323da2997bcba63
  - Path(s): local-ci/verification/clean_project/LATEST/*
  - Files: after/git_files.txt, git_size.txt, git_status.txt, workdir_size.txt; before/git_commit.txt, git_files.txt, git_size.txt, git_status.txt, workdir_size.txt; inventory/run_timestamp.txt, top_200_tracked_largest.tsv, tracked_file_sizes.tsv, tracked_junk_hits.tsv, tracked_over_5mb.tsv, tracked_suspect_extensions.tsv; proof/PROOF_INDEX.md, proof/SHA256SUMS.txt; reports/CLEAN_REPORT.md; security/secret_pattern_hits_redacted.txt, security/sensitive_files_found.txt

## Current Actions
- All local-ci/verification/** paths have been untracked (`git rm --cached -r local-ci/verification`).
- .gitignore updated to include `local-ci/verification/` and common runtime artifacts.
