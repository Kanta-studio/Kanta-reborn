"""Static integration regression checks for optional Filipino speech packs.

These tests verify that installation remains user-initiated and separate
from bundled assets, not that voice quality or hardware routing is accepted.
"""
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project.yml"
PACK = ROOT / "Sources/App/KantaOfflineSpeech.swift"
VOICE = ROOT / "Sources/App/KantaVoiceSearch.swift"
SETTINGS = ROOT / "Sources/App/KantaSettingsView.swift"
INFO = ROOT / "Config/GeloKaraoke-Info.plist"


class FilipinoSpeechContractTests(unittest.TestCase):
    def test_package_is_pinned_only_to_ios_app(self):
        project = PROJECT.read_text()
        package = (ROOT / "Package.swift").read_text()
        self.assertIn("argmaxinc/argmax-oss-swift.git", project)
        self.assertIn("exactVersion: 1.1.0", project)
        self.assertIn("product: WhisperKit", project)
        self.assertNotIn("argmaxinc/argmax-oss-swift", package)

    def test_installs_multilingual_base_by_explicit_action(self):
        source = PACK.read_text()
        self.assertIn('static let modelVariant = "base"', source)
        self.assertIn('static let modelRepository = "argmaxinc/whisperkit-coreml"', source)
        self.assertNotIn('modelVariant = "base.en"', source)
        self.assertIn("func downloadWithConsent() async", source)
        self.assertIn("variant: Self.modelVariant", source)
        self.assertIn("excluded.isExcludedFromBackup = true", source)
        self.assertIn("WhisperKitConfig(", source)
        self.assertIn("options: .atomic", source)
        self.assertIn("func removeDownloadedModel() throws", source)

    def test_short_lived_audio_and_local_tagalog_transcription(self):
        source = PACK.read_text()
        self.assertIn("AVAudioRecorder(", source)
        self.assertIn('language: "tl"', source)
        self.assertIn('try? FileManager.default.removeItem(at: audioFile)', source)
        self.assertIn('try? FileManager.default.removeItem(at: recordingURL)', source)
        self.assertIn("private func restoreAudioSession()", source)
        self.assertIn("KantaSpeechQueryNormalizer.normalized(result)", source)
        self.assertNotIn("URLSession.shared.upload", source)

    def test_language_controls_reuse_one_model_manager(self):
        voice = VOICE.read_text()
        settings = SETTINGS.read_text()
        self.assertIn("KantaFilipinoModelStore.shared", voice)
        self.assertIn("KantaFilipinoPackControls()", voice)
        self.assertIn("KantaFilipinoPackControls()", settings)
        self.assertIn("offline.begin(pack: pack)", voice)
        self.assertIn("offline.finish(pack: pack)", voice)
        self.assertIn("query = offline.finalQuery", voice)
        self.assertIn("microphoneBusy", voice)

    def test_usage_descriptions_cover_both_speech_paths(self):
        with INFO.open("rb") as f:
            plist = plistlib.load(f)
        mic = plist["NSMicrophoneUsageDescription"]
        speech = plist["NSSpeechRecognitionUsageDescription"]
        self.assertIn("voice song search", mic)
        self.assertIn("Apple", speech)

    def test_no_model_weights_accidentally_bundled(self):
        disallowed = [".mlmodelc", ".mlmodel", ".mlpackage", ".bin", ".safetensors"]
        for path in (ROOT / "Sources/App", ROOT / "BG/BUNDLED"):
            for item in path.rglob("*"):
                self.assertFalse(any(item.name.endswith(x) for x in disallowed), str(item))


if __name__ == "__main__":
    unittest.main()
