# STATUS

What is done today
- A single-entrypoint autopilot was added: `tools/autopilot/run.sh` that runs build/test gates and writes evidence (inventory, logs, reports, proof) into `local-ci/verification/finish_today/LATEST/` (this path is ignored by git).

What is ready to ship now
- Code and configuration needed for deployment are present at repository root: `firebase.json`, `firestore.rules`, `storage.rules`, and `firestore.indexes.json`.
- CI workflow `/.github/workflows/autopilot_release.yml` will run the autopilot and upload the `finish-today-evidence` artifact.

What is blocked only by secrets/deployment
- Running real payment or production deploy requires these secrets set in CI or environment: see `docs/ENVIRONMENT_VARIABLES.md`.

Where proof is
- Evidence bundle (artifact from CI): finish-today-evidence (GitHub Actions artifact pointing to `local-ci/verification/finish_today/LATEST/**`).

Last run verdict + commit
- Last commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'no-git')
- Run status: not yet executed in this branch for the new autopilot
