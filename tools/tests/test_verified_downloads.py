import importlib.util
import io
import pathlib
import plistlib
import unittest
import zipfile
import hashlib

spec = importlib.util.spec_from_file_location("prepare", pathlib.Path(__file__).parents[1] / "prepare-verified-downloads.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class DownloadContracts(unittest.TestCase):
    def test_live_manifest_uses_current_repository_and_run_specific_artifact_links(self):
        root = pathlib.Path(__file__).parents[2]
        manifest = __import__("json").loads((root / "apps/web/downloads.json").read_text())
        self.assertEqual(manifest["repository"], "usermalik20-del/Kanta-reborn")
        self.assertEqual(manifest["retentionDays"], 7)
        for platform, page in (("android", "android.html"), ("ios", "ios-download.html")):
            build = manifest[platform]
            link = f"https://github.com/{manifest[\"repository\"]}/actions/runs/{build[\"run\"]}/artifacts/{build[\"artifact\"]}"
            self.assertIn(link, (root / "apps/web" / page).read_text())
    def test_failed_or_moved_source_is_rejected(self):
        expected = module.BUILDS["android"]
        artifact = dict(id=expected["artifact"], expired=False, workflow_run=dict(id=expected["run"]))
        with self.assertRaises(ValueError):
            module.accepted(dict(id=expected["run"], conclusion="failure", head_sha=expected["source"]), artifact, expected)
        with self.assertRaises(ValueError):
            module.accepted(dict(id=expected["run"], conclusion="success", head_sha="wrong"), artifact, expected)

    def test_expired_artifact_is_rejected(self):
        expected = module.BUILDS["android"]
        with self.assertRaises(ValueError):
            module.accepted(dict(id=expected["run"], conclusion="success", head_sha=expected["source"]),
                            dict(id=expected["artifact"], expired=True, workflow_run=dict(id=expected["run"])), expected)

    def test_ambiguous_application_is_rejected(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("one/app-debug.apk", b"one")
            archive.writestr("two/app-debug.apk", b"two")
        with zipfile.ZipFile(io.BytesIO(data.getvalue())) as archive:
            with self.assertRaises(ValueError):
                module.one(archive, "/app-debug.apk")

    def test_root_artifact_member_and_redirect_credentials(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("KANTA-personal-unsigned.ipa", b"device app")
        with zipfile.ZipFile(io.BytesIO(data.getvalue())) as archive:
            self.assertEqual(module.one(archive, "/KANTA-personal-unsigned.ipa"), b"device app")
        request = module.urllib.request.Request("https://api.github.com/artifact",
                                               headers={"Authorization": "Bearer fixture"})
        redirected = module.SafeRedirect().redirect_request(request, None, 302, "Found", {},
                                                            "https://storage.example/artifact.zip")
        self.assertIsNone(redirected.get_header("Authorization"))

    def test_unsigned_device_identity_and_checksum(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as archive:
            archive.writestr("Payload/KANTA.app/Info.plist", plistlib.dumps(dict(CFBundleIdentifier="com.gelo.karaoke", CFBundleSupportedPlatforms=["iPhoneOS"])))
            archive.writestr("Payload/KANTA.app/THIRD_PARTY_AUDIO_NOTICES.txt", "fixture notices")
        app = data.getvalue()
        info = dict(run_id=str(module.BUILDS["ios"]["run"]), platform="iPhoneOS", signed=False, personal_signing=True, icloud_available=False)
        checksum = hashlib.sha256(app).hexdigest()
        module.validate_ipa(app, info, checksum)
        with self.assertRaises(ValueError):
            module.validate_ipa(app + b"changed", info, checksum)
        with self.assertRaises(ValueError):
            module.validate_ipa(app, dict(info, signed=True), checksum)

if __name__ == "__main__":
    unittest.main()
