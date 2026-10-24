# KANTA public website

Static first-party pages recovered from the captured October 15 website evidence. Android and iOS remain separate native applications under their own directories.

Deploy this directory as a static site, with no install or build command. `vercel.json` keeps the Content Security Policy scoped to each public HTML route: only the homepage permits the Google tag and Google Analytics connection, while every other page—including `/songbook`—uses same-origin scripts and `connect-src 'none'`. The homepage analytics initializer lives in `analytics.js`, so its script policy does not require `unsafe-inline`. The browser Songbook script and stylesheet remain byte-identical to the immutable evidence; its files, codes and searches are processed locally under the strict route policy.

Downloads point to verified Actions artifacts in the current `usermalik20-del/Kanta-reborn` repository and require GitHub sign-in. Artifact retention is seven days; update `downloads.json` and both platform pages whenever fresh main-branch artifacts are published. The Android APK is debug-signed. The iPhoneOS IPA is unsigned, needs separate trusted personal signing and has no iCloud Save. Neither is a store release.

Run `python3 tools/verify-website.py`, `python3 -m unittest tools.tests.test_website_security_contract`, and `node --check apps/web/songbook.js apps/web/analytics.js` from the repository root. Website validation checks every route's CSP and the deployment workflow gates production publishing on the same contract. Native apps are not rebuilt by the website-only workflow. Preserve the previous deployment for rollback.

The recovery evidence in `docs/evidence/website/2026-10-15` remains immutable. Original legal and software notices are retained; current Android implementation and signing statements supersede unavailable-repository feature claims.

