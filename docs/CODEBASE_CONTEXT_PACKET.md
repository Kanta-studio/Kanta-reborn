# Codebase context packet

## Active website repair — October 24, 2026

Main advanced from `ebe2f7a` through [`12917944`](https://github.com/usermalik20-del/Kanta-reborn/commit/12917944cb00c9023bbceef26f6c0980affdcf70) to [`926b061`](https://github.com/usermalik20-del/Kanta-reborn/commit/926b06163d8ddc11565febfcdb9ed4c685dda8e1). Website validation [run #40063520436](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40063520436) failed first because the restored homepage still linked to the old `kanta-gelo/Kanta-reborn` path. The Vercel deployment [run #40063520390](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40063520390) stopped at that validation failure. The verifier also contained obsolete assumptions for a global analytics-free CSP.

Candidate branch `fix/website-csp-route-isolation-20261024` corrects the repository link, scopes CSP to the ten canonical HTML routes, allows Google tag/Analytics only on the homepage, keeps `connect-src 'none'` on Songbook and all other pages, and serves analytics initialization from same-origin `apps/web/analytics.js`. Static verification, focused regression tests and automatic website/deployment workflow wiring enforce the policy. Exact-head PR CI and production response-header checks are pending.

## iOS release acceptance remains separate

PR [#58](https://github.com/usermalik20-del/Kanta-reborn/pull/58) remains an unverified presentation repair at candidate head `6045fba0b46d3de7efc34d102aff60af20ca3288`. The last recorded main iPhone/iPad walkthrough failure is [run #39992413296](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/39992413296) on older source `8114847`; the latest PR #58 candidate has no green walkthrough evidence. Do not infer simulator acceptance from website or reconstruction checks.

## Artifact boundary

The latest verified unsigned iOS archive is from main source `ebe2f7a`, [run #40009518032](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032), artifact [#12526580325](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032/artifacts/12526580325). It is an unsigned personal-signing input, not a signed or directly installable release. Re-check expiry and source identity before publishing download links.
