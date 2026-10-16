# Verified preview downloads

The read-only packaging workflow preserves accepted application bytes without compilation or signing. Android 0.5.0 source `4da765035dd3cbeec6e69f38581138225b706e6d` passed run [38826875086](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38826875086), including 201 domain assertions, 60 emulator checks and the merged-APK permission/runtime-notice gate. iOS source `3c12a1fb962ac956250a8f238c01eace13f560d2` passed device packaging and both simulator walkthroughs in run [38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805).

Each platform bundle contains one application, SHA256.txt, build-info.json and README.txt. The instrumentation APK is excluded. Packaging checks successful run/source/artifact identity, expiry, available artifact digest, archive bounds and app contents. The IPA retains its original checksum, bundle identity, software notices and unsigned personal-signing flags. Authorization headers are stripped on storage redirects.

Only kanta-gelo dispatch or the owner-approved-download-packaging PR label runs packaging. Outputs require GitHub sign-in and last 30 days. A failure never replaces accepted app bytes or creates a public release. iOS requires separate trusted personal signing and has no iCloud Save. Android remains debug-signed. Test builds from separate CI machines can use different debug signing certificates, so installing another preview may require uninstalling and losing app-private state; keep original media and explicit exports backed up.

Website download links must change only after packaging succeeds and provides actual artifact identities. Earlier bundles retain their original source/run metadata. Physical-device and production-distribution acceptance remain open.
