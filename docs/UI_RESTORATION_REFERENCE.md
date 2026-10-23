# KANTA pre-suspension UI restoration reference

Status: native implementation candidate added; compilation, runtime screenshots and visual acceptance are pending.

## Scope and branch isolation

Restore the iOS Library/Storage and Karaoke Host visual hierarchy from owner-provided October 18, 2026 screenshots. Keep this work separate from PR #51 YouTube playback hardening; do not merge incomplete visual work. Respect root AGENTS.md and docs/ARCHITECTURE.md before editing native screens. Preserve current functional behavior and accessibility.

## Library

- Deep midnight-purple gradient background; back button and large Library title.
- First rounded bordered card: **Your karaoke, your storage**, brief local-privacy explanation, **Add a karaoke folder** instructions, full-width purple **Add Karaoke Folder** primary action.
- Google Drive is a disabled secondary row marked **COMING LATER**, with no enabled authentication or Drive access.
- Second rounded card is the disconnected-library empty state: **No library connected**, a simple folder icon, **Choose a Folder**, and Files/iCloud Drive/security-scoped bookmark explanation.
- Connected library state must retain existing import and bookmark functionality; do not show the empty state when connected.

## Karaoke Host

- Black page background; back and expand controls; prominent Karaoke Host heading.
- Primary stage card with small cyan NOW SINGING label, current song title, search/camera/expand actions, scenic lyrics artwork, visible synchronized lyrics and subtle KANTA watermark.
- Large cyan local Play/Pause button, separate local Next button, and compact Up Next summary.
- Remote Control is a collapsed-by-default expandable inline panel below the stage, not an overlay. Expanded controls include now-singing, search/code input, keypad and reservation actions.
- External TV / Stage Display information appears below Remote Control, not inside the primary stage card.
- YouTube has its own playback surface and transport; no YouTube controls are routed through local Play/Pause/Next.

## Acceptance criteria

1. Match reference hierarchy, spacing, colors, typography and card structure on iPhone-sized screens without clipping or unnecessary duplicate controls.
2. Both Remote Control collapsed and expanded states remain usable; stage stays visible when expanded.
3. Folder import, connected/disconnected state, bookmarks, local playback, queue, and external display behavior remain functional.
4. Accessibility labels, Dynamic Type, safe areas and portrait/landscape layout remain usable.
5. Validate with targeted UI tests and fresh screenshots; do not treat compilation alone as visual verification.
6. Resolve any conflicts with PR #51 by preserving independent player ownership; keep commits and CI gates separate.

Reference screenshots were supplied in the conversation and are not bundled in the repository. This document describes the visual contract; it does not claim pixel-perfect implementation.
