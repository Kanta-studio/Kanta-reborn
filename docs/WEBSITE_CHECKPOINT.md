# Restored website checkpoint

Validated source: `e8c670c7ea4ebba3add5c48982d23cc98ca52b14`.
Static CI: [38813213292](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38813213292), successful.
Preview deployment: `dpl_GhDSBwKx58bGNjr4VNQBNyvyrU1J`.
Preview: https://kanta-public-qojzl46j4-gelo-tech.vercel.app

## Restored scope

The active first-party website lives under `apps/web`, separate from `apps/android` and `apps/ios`. Immutable recovery evidence remains under `docs/evidence/website/2026-10-15`. Current platform pages describe only the accepted downloadable builds, replace unavailable old-repository download links, disclose unsigned/debug status and missing restored capabilities, and retain software/legal notices including TinySoundFont.

The private browser reader and its stylesheet are byte-identical to the captured evidence. No song files, access codes or searches are uploaded. CSP retains `connect-src 'none'`, self-hosted scripts/styles and no inline-script allowance.

Download bundles are from successful packaging run [38812761100](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38812761100), preserving original accepted APK/IPA bytes. GitHub sign-in is required; artifacts expire after 30 days. No public app release, Apple signing or store publication was performed.

## Evidence and limits

Static checks passed for ten public pages, local routes and anchors, duplicate IDs, required metadata, unchanged private reader, CSP and manifest-to-download identity. Node syntax validation passed.

All ten preview pages and public CSS, JavaScript and download manifest returned HTTP 200 with their submitted content. The homepage also contained Vercel's preview-feedback script appended after the document; the existing CSP blocks that external script. Configuration is deployment input, not a public asset.

A browser inspection was attempted, but the runtime reported `environment_offline`. Visual inspection, mobile hit-target testing and an interactive browser Songbook walkthrough were therefore not completed in this session. Previous browser cryptographic interoperability checks remain valid because the reader script is unchanged.

The verified preview is eligible for promotion to the existing `kanta-public.vercel.app` alias without rebuilding. Prior production deployment `dpl_7XxphF9QFPMArBbiaWgs2hw3oDvH` is retained for rollback. Record the actual promotion result separately; this checkpoint does not claim a promotion before it occurs.
