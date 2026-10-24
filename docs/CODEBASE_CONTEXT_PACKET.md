# Codebase context packet

## Active website CSP repair — October 24, 2026

Main advanced from `ebe2f7a` through [`12917944`](https://github.com/usermalik20-del/Kanta-reborn/commit/12917944cb00c9023bbceef26f6c0980affdcf70) to [`926b061`](https://github.com/usermalik20-del/Kanta-reborn/commit/926b06163d8ddc11565febfcdb9ed4c685dda8e1). The latest commit's website validation [run #40063520436](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40063520436) failed in `tools/verify-website.py`; Vercel deployment [run #40063520390](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40063520390) failed the same validation gate and skipped deployment. The prior candidate's website validation [run #40062140255](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40062140255) and deployment [run #40062140248](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40062140248) passed on `12917944`.

The confirmed defect was a stale global-CSP assertion. Candidate branch `fix/website-csp-route-isolation-20261024` scopes CSP to the ten canonical HTML routes, allows Google tag/Analytics only on the homepage, keeps `connect-src 'none'` on Songbook and all other pages, and serves analytics initialization from same-origin `apps/web/analytics.js`. Static verification, focused regression tests and automatic website/deployment workflow wiring enforce the policy. PR CI and production response-header checks remain pending until the exact candidate is validated and deployed.

## iOS release acceptance remains separate

PR [#58](https://github.com/usermalik20-del/Kanta-reborn/pull/58) remains an unverified presentation repair at candidate head `6045fba0b46d3de7efc34d102aff60af20ca3288`. The last recorded main iPhone/iPad walkthrough failure is [run #39992413296](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/39992413296) on older source `8114847`; no green walkthrough on the current PR #58 head has been established. Do not infer simulator acceptance from website or reconstruction checks.

## Artifact boundary

The latest verified unsigned iOS archive is from main source `ebe2f7a`, [run #40009518032](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032), artifact [#12526580325](https://github.com/usermalik20-del/Kanta-reborn/actions/runs/40009518032/artifacts/12526580325). It is an unsigned personal-signing input, not a signed or directly installable release. Re-check expiry and source identity before publishing download links.
