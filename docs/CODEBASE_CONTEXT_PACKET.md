# Codebase context packet

## Latest main state — October 24, 2026

Main is at [`afd83e5`](https://github.com/usermalik20-del/Kanta-reborn/commit/afd83e52530811679bda3730945b7dd03f421bd8), merged via [PR #63](https://github.com/usermalik20-del/Kanta-reborn/pull/63). Website validation [run #40064491975](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40064491975) and Vercel deployment [run #40064491915](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40064491915) passed. Production deployment [`dpl_F9itgfRjxfs5LqfRuYxvyrxXHg1y`](https://vercel.com/gelo-tech/kanta-public/F9itgfRjxfs5LqfRuYxvyrxXHg1y) is READY.

The homepage now returns HTTP 200 with its route-specific CSP, external stylesheet and same-origin `analytics.js`; it contains no inline script and points to the canonical repository. The other nine canonical routes also return HTTP 200. `/songbook` and the eight other non-home routes retain `connect-src 'none'` and `script-src 'self'`; only the homepage permits the Google tag/Analytics allowlist. `/style.css` and `/analytics.js` return HTTP 200. The verified details are in the website repair ledger.

## Remaining iOS release-acceptance blocker

PR [#58](https://github.com/usermalik20-del/Kanta-reborn/pull/58) remains open at candidate head `6045fba0b46d3de7efc34d102aff60af20ca3288`, with its base still at `6f335c2` and a dirty/merge-conflict state. The latest recorded walkthrough on an earlier candidate is [run #40003404013](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40003404013): iPhone passed, but three iPad keypad tests failed. The last main walkthrough failure is [run #39992413296](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/39992413296) on older source `8114847`. No walkthrough run on the current PR #58 head has established acceptance. The next iOS action is to reconcile PR #58 with current main, trigger the full iPhone/iPad workflow on the exact updated head, and fix any remaining failure before release.

## Release artifact boundary

The previous verified unsigned iOS input is from `ebe2f7a`, [run #40009518032](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032), artifact [#12526580325](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032/artifacts/12526580325). It is unsigned and requires personal signing; it is not a signed or directly installable release. The main unsigned-artifact workflow for `afd83e5` is still separate from iOS walkthrough acceptance. Do not update public download links until the exact release candidate passes its acceptance gate.

## iOS Stage repair and exact-SHA release gate — October 24, 2026

The previous PR #58 candidate `6045fba0b46d3de7efc34d102aff60af20ca3288` has no successful current-head walkthrough evidence. The earlier candidate [run #40003404013](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40003404013) passed iPhone but failed three iPad keypad tests. The repair must consolidate embedded Host/Stage sheet ownership and preserve separate fullscreen ownership; scope remote accessibility IDs to the actual toggle and bound menu test durations. The new candidate branch `fix/ios-stage-sheets-and-exact-sha-release-gate-20261024` is pending hosted reconstruction and full iPhone/iPad validation.

The verified-download packager must discover artifacts from successful main runs for the exact same SHA (reconstruction, unsigned iOS archive and full walkthrough), reject expired/cross-run artifacts, verify IPA metadata/checksums, and remain manual-dispatch only. No unsigned archive is a signed or directly installable release, and public download links must not advance before the exact-SHA acceptance gate passes.
