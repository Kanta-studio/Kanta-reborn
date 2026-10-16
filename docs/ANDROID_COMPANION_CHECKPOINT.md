# KCP1 Android companion protocol and acceptance

## Scope and trust

Android 0.10 candidate; Java 17/Views, minSdk 26 and targetSdk 36. No new library or cloud service. The recovered iOS plaintext remote is unchanged and incompatible. This experimental protocol has not received independent security review and offers no forward secrecy: possession of a recorded session and its pairing code permits deriving its keys. Do not advertise cross-platform compatibility or audited security.

One host binds one explicitly selected RFC1918 IPv4 interface on TCP 45731; the client accepts a numeric RFC1918 IPv4 address, with no DNS, wildcard bind, discovery, global address or automatic reconnection. The INTERNET platform permission is required for Java sockets; target SDK 36 does not request ACCESS_LOCAL_NETWORK (Android guidance: https://developer.android.com/privacy-and-security/local-network-permission). Network or permission failure closes the session. Private IPv4 restrictions do not prevent VPN/router forwarding; use a trusted network and never forward this port.

## Authentication and records

Host generates 16 random secret bytes displayed as 32 hexadecimal characters, never a low-entropy PIN. Pairing expires after five minutes, after three failed authentications, or after the first successful companion. The UI protects its window from screenshots and does not save credential fields or use automatic clipboard operations. Share the full code only with a trusted person. Session credentials exist only in memory. Stop, backgrounding, connection failure, ten-minute expiry, fifteen-second idle read timeout or the 512-command bound retire the session. Returning cannot restart it.

The host sends uint32 big-endian magic 0x4b435031 and a random 32-byte host nonce. The client sends a random 32-byte client nonce and HMAC-SHA256(PSK, transcript || ASCII(client-proof)); the host verifies and returns HMAC-SHA256(PSK, transcript || ASCII(host-proof)). Transcript is magic || hostNonce || clientNonce. No pairing secret or metadata is sent in plaintext. Each handshake receives new nonces.

HKDF-SHA256 extract uses SHA256(transcript) as salt and the 16-byte PSK as IKM. Expand is a single block HMAC(PRK, transcript || ASCII(client-to-host or host-to-client) || byte 0x01). Its 32-byte output is a separate AES-256-GCM key for each direction. Records are uint32 ciphertextLength || uint64 sequence || ciphertext+16-byte tag. The 12-byte nonce is uint32 direction (1 client, 2 host) || uint64 sequence; AAD is magic || direction || sequence. Each direction starts at zero, accepts exactly the next sequence and closes before counter wrap. Length is 16–32768 before allocation. There is no downgrade or plaintext fallback. Primitives use Android/JCA HmacSHA256 and AES/GCM/NoPadding.

## Command ownership and limits

Requests encode UUID (two big-endian signed longs), action, argument and singer as uint16 UTF-8 byte length + bytes. Fields are bounded to 16/128/80 UTF-16 code units and four times those byte counts; decoding is strict UTF-8, with no trailing data. Actions: snapshot, search, reserve, cancel, play, pause, next. Unsupported commands and malformed records close the connection. No path, import, sensor, effects or scoring command exists.

One socket worker serializes the entire authenticated request/response exchange. Host mutations run on the main Looper through the existing SessionController/FIFO, checking active run, foreground, revocation, expiry and cancellation immediately before execution. A main-thread response timeout revokes the run and cancels queued work. Replay identities retain their original response within the run, including intentional repeated-song distinctions; the 512-entry cache never evicts or permits a previously executed identity to run again. Pairing a fresh session creates a new idempotency boundary; there is no durable reconnect retry guarantee.

Authenticated response text is strict UTF-8 and limited to eight levels of nesting before recursive JSON parsing. Replies are bounded JSON metadata: request UUID, current title/playing, first ten queue reservations and up to ten matching playable songs. No media, file name, code secret, microphone audio or full catalog is exported. Search scans at most 10,000 cached song keys with query normalization once. Client polling every five seconds keeps the foreground session alive. One outstanding client request is allowed; additional button taps while it is busy are ignored.

## Candidate verification

Fresh Java 17 production-core/test compilation and 448 domain assertions passed, including 84 real-stream/adversarial companion checks. Prior 364 assertions remain enabled. Captured browser export/wrong-code/tamper interoperability and complete Swift test-layout guards passed. New emulator cases exercise actual local sockets, authenticated metadata search, authoritative reservations, duplicate-command replies, separate repeated turns, cancellation, sensor non-activation, background revocation and rejection of wildcard hosting. Hosted APK/lint and emulator acceptance are pending. Physical two-device Wi-Fi/Ethernet behavior, iOS interoperability and independent protocol review remain open. Public downloads remain on accepted 0.9 until successful changed-head acceptance and verified packaging.
