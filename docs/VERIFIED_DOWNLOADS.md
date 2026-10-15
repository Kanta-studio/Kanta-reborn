# Verified preview downloads

The download-packaging workflow copies application bytes from the accepted Android run [38807243721](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38807243721) and iOS run [38806377805](https://github.com/kanta-gelo/Kanta-reborn/actions/runs/38806377805). It does not compile, sign or alter either app.

Android source: `b3a6cd7c795e2aaea4e48254ede290b4f616d671`.
iOS source: `3c12a1fb962ac956250a8f238c01eace13f560d2`.

The read-only workflow checks successful run identity, source revision, artifact identity, expiry, available artifact digest, archive bounds and application contents. The iOS package additionally retains and checks the original IPA checksum, device bundle identity, required notices and unsigned personal-signing configuration. Redirects never forward the GitHub token to artifact storage.

Each platform bundle contains one application, SHA256.txt, build-info.json and README.txt. The Android instrumentation APK is excluded. The iOS IPA requires separate trusted personal signing; it is not directly installable, distributed through TestFlight, or entitled for iCloud Save.

Run the workflow manually after merge, or apply `owner-approved-download-packaging` to its pull request as kanta-gelo. Only that owner's dispatch or label starts the job. Outputs are retained for 30 days and GitHub requires sign-in to download Actions artifacts. A packaging failure never replaces an accepted build or publishes a public release.

Artifact availability is temporary. Website links must describe these as testing downloads and show the source build and signing restrictions. Physical-device audio, microphone, camera and latency acceptance remain separate from CI and simulator checks.
