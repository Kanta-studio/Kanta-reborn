"""Regression tests for unsigned physical-device AltStore IPA packaging."""
from __future__ import annotations

import importlib.util
import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "kanta_altstore_packager", ROOT / "Tools/package-altstore-ipa.py"
)
assert SPEC and SPEC.loader
packager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packager)


class AltStorePackagingTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        self.app = self.root / "KANTA.app"
        self.app.mkdir()
        (self.app / "KANTA").write_bytes(b"unsigned-test-executable")
        (self.app / "PrivacyInfo.xcprivacy").write_text("test privacy manifest")
        notices = self.app / "Licenses"
        notices.mkdir()
        (notices / "THIRD_PARTY_AUDIO_NOTICES.txt").write_text("MIT/BSD")
        self.info = {
            "CFBundleIdentifier": "com.gelo.karaoke",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "KANTA",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
        }
        self.rewrite_info()

    def rewrite_info(self):
        with (self.app / "Info.plist").open("wb") as output:
            plistlib.dump(self.info, output)

    def test_iphoneos_bundle_produces_ipa_payload(self):
        target = self.root / "KANTA-AltStore-unsigned.ipa"
        packager.package_unsigned_ipa(self.app, target)
        with zipfile.ZipFile(target) as zf:
            names = zf.namelist()
            self.assertIn("Payload/KANTA.app/Info.plist", names)
            self.assertIn("Payload/KANTA.app/KANTA", names)
            self.assertIn(
                "Payload/KANTA.app/Licenses/THIRD_PARTY_AUDIO_NOTICES.txt",
                names,
            )

    def test_rejects_simulator_app(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.rewrite_info()
        with self.assertRaisesRegex(packager.PackagingError, "simulator"):
            packager.validate_app(self.app)

    def test_rejects_foreign_app_and_missing_notices(self):
        self.info["CFBundleIdentifier"] = "com.another.app"
        self.rewrite_info()
        with self.assertRaisesRegex(packager.PackagingError, "bundle identifier"):
            packager.validate_app(self.app)
        self.info["CFBundleIdentifier"] = "com.gelo.karaoke"
        self.rewrite_info()
        (self.app / "Licenses/THIRD_PARTY_AUDIO_NOTICES.txt").unlink()
        with self.assertRaisesRegex(packager.PackagingError, "copyright"):
            packager.validate_app(self.app)

    def test_rejects_already_provisioned_app(self):
        (self.app / "embedded.mobileprovision").write_bytes(b"profile")
        with self.assertRaisesRegex(packager.PackagingError, "unsigned"):
            packager.validate_app(self.app)

    def test_rejects_non_ipa_output(self):
        with self.assertRaisesRegex(packager.PackagingError, ".ipa"):
            packager.package_unsigned_ipa(self.app, self.root / "wrong.zip")


if __name__ == "__main__":
    unittest.main()
