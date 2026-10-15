# KANTA Reborn engineering instructions

Read docs/ARCHITECTURE.md and docs/RECONSTRUCTION.md before implementation.
Preserve apps/ios/AGENTS.md product invariants within the iOS project; dated historical release claims do not describe this reconstruction.
Keep native iOS and Android source, dependencies, build systems and signing independent.
Use one authoritative playback/FIFO queue state owner per native app. Give each reservation a distinct identity, even for repeated songs. Score natural completion at most once per playback identity.
Keep scoring, camera preview, microphone monitoring and experimental DSP opt-in. Preserve imported source bytes. Never include user music catalogs, credentials or signing materials.
Update architecture and handover documentation when behavior or boundaries change. Distinguish recovered, reconstructed, compiled, tested and released.
Do not trigger GitHub Actions without explicit current authorization. Do not activate historical workflows during the recovery import.
Never overlay historical snapshots wholesale. Reconcile overlapping implementations and record provenance.
