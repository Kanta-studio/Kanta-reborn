# KANTA public website

Static first-party pages recovered from the captured October 15 website evidence. Android and iOS remain separate native applications under their own directories.

Deploy this directory as a static site, with no install or build command. `vercel.json` preserves clean routes and a restrictive Content Security Policy. The browser Songbook script and stylesheet are byte-identical to the immutable evidence; files, codes and searches are processed locally with network connections blocked by CSP.

Downloads point to verified 30-day Actions bundles from packaging run 38812761100 and require GitHub sign-in. The Android APK is debug-signed. The iPhoneOS IPA is unsigned, needs separate trusted personal signing and has no iCloud Save. Neither is a store release.

Run `python3 tools/verify-website.py` from the repository root, then `node --check apps/web/songbook.js`. The owner-gated website workflow performs these checks without rebuilding native apps. Always stage and inspect a preview before changing the public alias. Preserve the previous deployment for rollback.

The recovery evidence in `docs/evidence/website/2026-10-15` remains immutable. Original legal and software notices are retained; current Android implementation and signing statements supersede unavailable-repository feature claims.
