# Repository publishing practices

Owner's preference: minimize account/repository suspension risk through ordinary compliant engineering. The reason for the old account suspension has not been established here; no promise that any workflow prevents suspension is made.

Before publishing, review the actual change, content rights/provenance, credentials, workflows and artifact size. Publish one auditable branch/PR batch; reuse existing Git objects rather than repeatedly transferring unchanged files. Keep workflows bounded and auditable. On October 15, 2026, the owner granted standing authorization for CI and necessary repair reruns, with no user-imposed run-count limit; do not ask again for each run. Batch changes and investigate failures before rerunning. This does not override service quotas, policy denials or signing/release gates. Do not generate issues, releases, API traffic or CI runs merely to show activity.

Only first-party or explicitly licensed starter music, artwork and software may be distributed. User libraries, commercial songbooks, credentials, signing keys, microphone recordings and personal files do not belong in this repository. Imported user media remains app-private and byte-preserved. Original recovery evidence is distinct from material approved for a production release; legacy compatibility and licensing review remain release gates.

Follow GitHub enforcement and appeal requirements. Do not misrepresent account identity, claim a suspension reason without evidence, or automate attempts to evade restrictions. Stop on a permissions/policy denial, inspect its cause and use only authorized access.

YouTube integration must use the official player and preserve ads/player behavior; do not implement extraction or ad blocking.

Primary references reviewed 2026-10-15:
- https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies
- https://docs.github.com/en/site-policy/github-terms/github-terms-of-service
- https://docs.github.com/en/site-policy/acceptable-use-policies/github-appeal-and-reinstatement

## CI recording and publication boundaries

Routine implementation PRs run platform-matched compilation, lint, security and unit checks, without emulator screen recording. UI-related changes additionally receive short screenshot smoke tests. Full iPhone, iPad and Android walkthroughs and recordings are release/manual gates; a developer may enable short video on focused iOS diagnostic dispatch. Workflow permissions remain read-only and upload only first-party synthetic/demo test evidence. Keep screenshots free of private catalogs, pairing secrets and microphone recordings. Retain Actions captures for seven days; never publish or link newly built IPAs/APKs based solely on successful visual snapshots. Existing labels can still explicitly trigger deeper owner-approved validation, and full release checks are not silently bypassed.
