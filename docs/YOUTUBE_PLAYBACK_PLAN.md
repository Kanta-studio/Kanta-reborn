# YouTube playback — queued after reconstruction

Owner request: 2026-10-15. Preserve FIFO: finish and publish the current iOS restoration / Android foundation batch before implementing this integration.

## Product decision

Use the official visible embedded YouTube player, with its normal ads, controls, branding, links and playback verification intact. Do not add ad blocking, content extraction, audio separation, stream proxying, downloading or background playback. No claim of ad-free playback. Keep optional YouTube use separate from offline-first local playback.

## Functional mapping

| KANTA feature | YouTube integration boundary |
| --- | --- |
| Import | Add a validated YouTube video link as metadata; do not copy media bytes |
| Reservations / singers / Favorites | Route video references through the existing authoritative queue; preserve duplicate reservation identities |
| Play / pause / Next / volume | Official IFrame API commands and state events; Next selects the next authorized reservation |
| Tempo | Only playback rates returned by the official player's available-rate API |
| Pitch / stem isolation | Unsupported for YouTube media; disable those controls instead of extracting audio |
| Timed lyrics | Use lyrics already in the visible video; do not scrape captions or fabricate KAR timing |
| Scoring | Requires a separately licensed, time-aligned melody reference and validation; not automatically available from a YouTube video |
| Scenic / camera / branding | Must not cover, replace or obscure the YouTube player; use other UI regions |
| Fullscreen / TV | Use supported visible player presentation and verify platform restrictions; never create audio-only playback |
| Offline | Local licensed media only; no YouTube download cache |
| Privacy | Explicit opt-in Internet playback, YouTube/Google privacy links, correct embed identity/referrer; platform consent and policy review |
| Remote | Commands project the same host controller state; do not add another playback queue |

## Implementation acceptance

1. Finish current native reconstruction milestone and inspect exact APIs at that revision.
2. Add an explicit video-source type without breaking persisted local song IDs or queue semantics.
3. Use official WebView/IFrame integration on each native platform, correctly identified and sized, with lifecycle cleanup and stale-callback protection.
4. Validate state changes, unavailable/age/region/embed restrictions, interruption, cancellation, failed media preparation and mixed local/YouTube FIFO transitions.
5. Update privacy, rights, feature matrix and user guide before release. No API keys in clients or Git; in-app discovery via Data API requires separate quota/credential design.

## Primary references checked

- https://developers.google.com/youtube/terms/developer-policies — advertisements and player integrity restrictions.
- https://developers.google.com/youtube/terms/developer-policies-guide — no separated media, downloads or background play through the API.
- https://developers.google.com/youtube/iframe_api_reference — supported commands, playback rates and state events.
- https://developers.google.com/youtube/player_parameters — visible embedded-player parameters and minimum sizing.

This is a queued specification, not an implemented or released feature.

DNS filtering was checked: AdGuard documents that DNS filtering cannot reliably distinguish YouTube video ads from content on shared domains. Do not change device DNS or promise that a DNS provider removes in-video ads. Reference: https://adguard-dns.io/en/blog/dns-content-blocking-at-scale.html

## Implementation slice 1 — Android external-player handoff (candidate)

A working Android Control entry now accepts a manually pasted, bounded HTTPS video URL and opens its canonical `www.youtube.com/watch?v=...` URL in the user's official YouTube app or browser. Validation accepts `watch?v=`, `youtu.be`, `shorts`, `live` and supported embed links only from exact YouTube hosts; it rejects host spoofing, malformed IDs, credentials, ports, duplicate IDs and non-HTTPS URLs. URL tracking and playlist query fields are discarded, and the Android application does not persist the link. Core regression coverage exercises both allowed and malicious URL cases. The native Activity pauses karaoke through its existing `onStop` handling when launching the external player.

**Boundary:** This is a usable external handoff, not the official in-app IFrame player or integrated song queue. It adds no background playback, ad removal, caption extraction, storage, API key, media download, DNS workaround or new Android permission. iOS is untouched. The remaining acceptance checklist above is still open; do not advertise an in-app player or update release links based on this slice. Build and emulator validation are pending on the isolated feature branch.
