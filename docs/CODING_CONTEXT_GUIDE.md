# Codebase context guide

Retained from the owner's engineering guidance, 2026-10-15.

Before proposing production code or replacing a subsystem, inspect the current repository and produce a concise context packet. Do this directly in the online checkout; do not ask the owner to collect local files that are already available here.

## Required context packet

- **Stack and libraries:** actual build plugins, pinned versions, minSdk/targetSdk, Java/Kotlin settings, UI toolkit, dependency injection, persistence and audio/MIDI libraries. State when a suggested framework is not used.
- **Storage and search:** song fields, storage format/schema, indexes, DAO or repository queries, import boundaries and paging. Do not assume Room or FTS4 exists.
- **Audio:** how MIDI/KAR and audio are validated, decoded, prepared and played; engine ownership, timing, audio focus, output routes and lifecycle.
- **Network/remote:** implemented companion protocol, authentication, encryption, command identities, replay protection and revocation; state clearly if absent.
- **Performance:** measured bottlenecks separately from source-review risks. Include thread ownership, heavy work, allocations, bounds, cancellation and stale-result protection. Never claim measured latency from a source inspection.
- **Evidence:** exact source revision, changed/uncommitted state, checks run and checks still required.

## Files to inspect

App-level Gradle configuration; storage entities/DAOs or repositories; playback manager/service and MIDI parser; companion/server code; architecture, engineering instructions and release gates. Use actual paths and formats, including Groovy/Java when the project does not use Kotlin DSL/Kotlin.

## Choosing optimization work

Prioritize an observed reproducible issue or a concrete correctness defect. Inspect available diagnostics before asking the owner what is slow. Ask for device/scenario details only when the repository and existing evidence cannot establish the behavior. Preserve the single playback/FIFO state owner, import byte integrity, opt-in audio semantics, privacy and platform separation.

Keep `docs/CODEBASE_CONTEXT_PACKET.md` updated with architectural changes. This guide complements `AGENTS.md` and `docs/ARCHITECTURE.md`; it does not authorize CI, releases or unsupported feature claims.

## Comment style

Apply this standard to existing and new code across both platforms. Write concise engineering comments about intent, invariants, tradeoffs and non-obvious edge cases. Keep conversational progress and drafting notes out of production source. Preserve required licensing, attribution, provenance and original authorship/history.

Mandatory before substantive changes: read [Engineering architecture contract](ENGINEERING_ARCHITECTURE_CONTRACT.md) and complete its ownership/lifecycle/documentation checklist.
