# Verified preview downloads

The packaging workflow preserves accepted application bytes without compilation or signing. Android 0.4.0 source `2ced06c5c6063e15e227cc094b2462a36a03e7f2` passed run [38825170997](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38825170997), including 201 domain assertions and 47 emulator checks. iOS source `3c12a1fb962ac956250a8f238c01eace13f560d2` passed device packaging and both simulator walkthroughs in run [38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805).

Each platform bundle contains one application, SHA256.txt, build-info.json and README.txt. The instrumentation APK is excluded. Read-only packaging checks successful run/source/artifact identity, expiry, available artifact digest, archive bounds and app contents. The IPA retains its original checksum, bundle identity, software notices and unsigned personal-signing flags. Authorization headers are stripped on storage redirects.

Only kanta-gelo dispatch or the owner-approved-download-packaging PR label runs packaging. Outputs require GitHub sign-in and are retained for 30 days. A failure never replaces accepted app bytes or creates a public release. iOS requires separate trusted personal signing and has no iCloud Save. Android remains debug-signed; physical-device and production-distribution acceptance stay open.

The website's download manifest and platform pages must be updated only after packaging succeeds and provides actual artifact identities. Earlier bundles remain identified by their original source/run metadata.
