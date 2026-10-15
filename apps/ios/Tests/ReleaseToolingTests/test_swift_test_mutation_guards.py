"""Guard Swift Testing macros against mutating receiver capture regressions.

Swift Testing rewrites direct calls in #expect into argument-inspection
closures. Struct mutating methods can then be invoked on an immutable
closure receiver, causing compile-time failures. Capture the result in
a local before asserting, preserving exactly-once state transitions.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SwiftTestingMutationGuardTests(unittest.TestCase):
    def test_mutating_fixture_calls_are_evaluated_before_expect(self):
        targets = {
            "Tests/LocalNetworkControlTests/RemoteTransportTests.swift": [
                "cache.begin", "decoder.append"
            ],
            "Tests/GeloKaraokeCoreTests/KaraokeSessionHistoryTests.swift": [
                "session.finish"
            ],
            "Tests/GeloKaraokeCoreTests/PlaybackQueueTests.swift": [
                "queue.remove", "queue.move"
            ],
        }
        for filename, members in targets.items():
            with self.subTest(file=filename):
                contents = (ROOT / filename).read_text(encoding="utf-8")
                for member in members:
                    with self.subTest(method=member):
                        self.assertIn(member + "(", contents)
                        # Also catches multiline #expect(\n try decoder.append(...).
                        expression = (
                            r"#expect\s*\(\s*(?:try\s+)?!?\s*"
                            + re.escape(member) + r"\s*\("
                        )
                        self.assertNotRegex(
                            contents, expression,
                            f"Evaluate mutating {member} before #expect",
                        )


if __name__ == "__main__":
    unittest.main()
