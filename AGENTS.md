# KANTA Reborn engineering instructions

Read docs/ARCHITECTURE.md and docs/RECONSTRUCTION.md before implementation.
Preserve apps/ios/AGENTS.md product invariants within the iOS project; dated historical release claims do not describe this reconstruction.
Keep native iOS and Android source, dependencies, build systems and signing independent.
Use one authoritative playback/FIFO queue state owner per native app. Give each reservation a distinct identity, even for repeated songs. Score natural completion at most once per playback identity.
Keep scoring, camera preview, microphone monitoring and experimental DSP opt-in. Preserve imported source bytes. Never include user music catalogs, credentials or signing materials.
Update architecture and handover documentation when behavior or boundaries change. Distinguish recovered, reconstructed, compiled, tested and released.
Standing owner authorization (October 15, 2026): run CI and necessary failure-repair reruns without a user-imposed run-count limit or repeated permission requests. Batch coherent changes, inspect failures before rerunning, and respect platform quotas and policy denials. This supersedes older per-run approval requirements in recovered instructions. Signing, public releases and deployment retain their separate release gates. Do not activate historical workflows during the recovery import.
Never overlay historical snapshots wholesale. Reconcile overlapping implementations and record provenance.

Before substantive refactors, follow `docs/CODING_CONTEXT_GUIDE.md` and refresh `docs/CODEBASE_CONTEXT_PACKET.md` from actual source. Do not assume suggested libraries are installed, or confuse source-review risks with measured bottlenecks. Gather existing files directly from the online repository instead of asking the owner for local settings or copies.
Follow `docs/GITHUB_PUBLISHING_POLICY.md` for content review and bounded publication. Keep the queued official YouTube integration in `docs/YOUTUBE_PLAYBACK_PLAN.md` behind the current reconstruction; never add ad suppression or unsupported parity claims.
Apply this standard to existing and new code across both platforms. Use concise, professional engineering comments: explain intent, constraints, invariants and non-obvious edge cases. Avoid conversational progress notes, implementation narration and tool/model references in source comments. Preserve required licenses, copyrights, provenance and existing authorship records; do not rewrite history to imply a different author.

Follow docs/TESTING.md when reconciling or changing source: keep the complete test suite wired into its targets, run the layout preflight, compile all package test targets before execution, and preserve failure diagnostics. Fix production behavior or demonstrably invalid fixtures; never delete assertions, disable suites or suppress lint to hide a regression. Report compiler, test, app-build and device acceptance separately.
