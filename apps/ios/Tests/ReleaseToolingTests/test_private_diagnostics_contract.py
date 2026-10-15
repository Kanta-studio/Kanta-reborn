"""Fail-closed source safeguards for KANTA support diagnostics and Ad Hoc signing."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class PrivateDiagnosticsContractTests(unittest.TestCase):
    def test_explicit_opt_in_and_redacted_typed_codes(self):
        model = source("Sources/Core/Diagnostics/KantaDiagnosticTimeline.swift")
        implementation = source("Sources/App/KantaSupportDiagnostics.swift")
        self.assertIn("public enum KantaDiagnosticCode: String, Codable", model)
        self.assertIn("maximumEntries = 200", model)
        self.assertIn("retentionSeconds: TimeInterval = 7 * 24 * 60 * 60", model)
        self.assertNotIn("case arbitrary(", model)
        self.assertIn('defaults.bool(forKey: Key.enabled)', implementation)
        self.assertIn("guard enabled else { return }", implementation)
        self.assertIn(".completeFileProtection", implementation)
        self.assertIn("values.isExcludedFromBackup = true", implementation)
        self.assertIn("timeline.prune()", implementation)
        self.assertIn("func clear()", implementation)
        self.assertIn("try? FileManager.default.removeItem(at: timelineURL)", implementation)
        self.assertIn("private struct KantaSupportReport: Encodable", implementation)
        for prohibited in (
            "songTitle:", "singerName:", "password:", "pin:", "ipAddress:",
            "filePath:", "microphoneSamples:", "rawError:"
        ):
            self.assertNotIn(prohibited, implementation)

    def test_share_only_by_user_and_notice_present(self):
        ui = source("Sources/App/KantaSettingsView.swift")
        self.assertIn("Keep local diagnostic events", ui)
        self.assertIn("Prepare support report", ui)
        self.assertIn("ShareLink(item: export)", ui)
        self.assertIn("Erase local diagnostic history", ui)
        implementation = source("Sources/App/KantaSupportDiagnostics.swift")
        self.assertNotIn("URLSession", implementation)
        self.assertNotIn("HTTPURLResponse", implementation)
        self.assertNotIn("AnalyticsSDK", implementation)
        policy = source("PublicSite/privacy.html")
        self.assertIn('id="diagnostics"', policy)
        self.assertIn("seven days", policy)
        self.assertIn("does not automatically send", policy)
        legal = source("Sources/Features/Legal/LegalView.swift")
        self.assertIn('GeloSectionCard("Optional diagnostic reports")', legal)

    def test_audio_diagnostics_are_not_issued_on_render_callback(self):
        monitor = source(
            "Sources/Infrastructure/MicrophoneScoring/MicrophonePitchMonitor.swift"
        )
        callback = monitor.split("engine.inputNode.installTap(", 1)[1]
        self.assertNotIn("onDiagnosticEvent?", callback.split("hasTap = true", 1)[0])
        self.assertIn("onDiagnosticEvent?(.permissionRequested)", monitor)
        self.assertIn("onDiagnosticEvent?(.failed)", monitor)
        self.assertIn("onDiagnosticEvent?(.stopped)", monitor)
        self.assertIn("wasAudible != isMonitorAudible", monitor)
        self.assertIn("oldRoute != monitoringRoute", monitor)

    def test_beta_signing_is_manual_and_never_sends_private_keys(self):
        workflow = source(".github/workflows/manual-ad-hoc-ipa.yml")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("\n  push:", workflow)
        self.assertNotIn("\n  pull_request:", workflow)
        self.assertIn('test "${{ github.ref }}" = "refs/heads/main"', workflow)
        self.assertIn("KANTA_ADHOC_MOBILEPROVISION_BASE64", workflow)
        self.assertIn("ProvisionedDevices", workflow)
        self.assertIn("com.gelo.karaoke", workflow)
        self.assertIn('method": "release-testing"', workflow)
        self.assertNotIn("curl https://betadrop", workflow)
        self.assertNotIn("betadrop.app/upload-ipa", workflow)
        self.assertIn("Destroy temporary signing credentials", workflow)
        self.assertIn("retention-days: 3", workflow)


if __name__ == "__main__":
    unittest.main()
