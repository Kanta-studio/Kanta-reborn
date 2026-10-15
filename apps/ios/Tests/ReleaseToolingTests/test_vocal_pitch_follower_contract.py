"""Source-boundary checks for KANTA's experimental native vocal tuning."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class VocalPitchFollowerContractTests(unittest.TestCase):
    def read(self, relative_path: str) -> str:
        return (ROOT / relative_path).read_text(encoding="utf-8")

    def test_native_dsp_path_retained_and_new_follower_used(self):
        monitor = self.read(
            "Sources/Infrastructure/MicrophoneScoring/MicrophonePitchMonitor.swift"
        )
        self.assertIn("private let voicePitch = AVAudioUnitTimePitch()", monitor)
        self.assertIn("private var pitchFollower = VocalPitchFollower()", monitor)
        self.assertIn("voicePitch.pitch = pitchFollower.update(", monitor)
        self.assertIn("engine.connect(\n                    engine.inputNode, to: soundpipeCorrect.avAudioNode", monitor)
        self.assertIn("engine.connect(voicePitch, to: voiceEQ", monitor)
        self.assertIn("PitchCorrect(", monitor)
        self.assertIn("soundpipeCorrect.setScaleFrequencies(", monitor)
        self.assertIn("self.observation = observation", monitor)
        self.assertIn("captureGeneration == generation", monitor)
        self.assertNotIn("smoothedCorrectionCents", monitor)

    def test_routing_and_stop_remain_fail_closed(self):
        monitor = self.read(
            "Sources/Infrastructure/MicrophoneScoring/MicrophonePitchMonitor.swift"
        )
        self.assertIn("monitoringRoute.permitsLiveMonitor", monitor)
        self.assertIn("voiceMixer.outputVolume = 0", monitor)
        self.assertGreaterEqual(monitor.count("pitchFollower.reset()"), 3)
        self.assertIn("case .headphones:", monitor)
        self.assertIn("case .usbAudio:", monitor)
        self.assertIn("case .lineOut:", monitor)

    def test_quantizer_confidence_and_limits_remain(self):
        quantizer = self.read("Sources/Core/Playback/VocalPitchCorrection.swift")
        follower = self.read("Sources/Core/Playback/VocalPitchFollower.swift")
        self.assertIn("confidence.isFinite, confidence >= 0.76", quantizer)
        self.assertIn("frequencyHz <= 1_000", quantizer)
        self.assertIn("Float(min(max(cents, -200), 200))", quantizer)
        self.assertIn("pendingCount >= 2", follower)
        self.assertIn("missingCount >= 2", follower)
        self.assertIn("if lastRoot != config.root || lastScale != config.scale", follower)

    def test_no_third_party_dsp_dependency_was_misrepresented(self):
        decision = self.read("Docs/VOCAL_DSP_LICENSE_AND_ACCEPTANCE.md")
        self.assertIn("SoundpipeAudioKit", decision)
        package = self.read("Package.swift")
        project = self.read("project.yml")
        self.assertNotIn("Signalsmith", package + project)
        self.assertIn('exact: "5.7.4"', package)
        self.assertIn('exact: "5.7.2"', package)
        self.assertIn('.product(name: "SoundpipeAudioKit"', package)
        self.assertIn("Resources/Licenses", project)
        notices = self.read("Resources/Licenses/THIRD_PARTY_AUDIO_NOTICES.txt")
        self.assertIn("BSD 3-Clause", notices)
        self.assertIn("Copyright (c) 2003-2010 Mark Borgerding", notices)
        for name in ["SoundpipeAudioKit", "AudioKitEX", "Tonic", "KissFFT"]:
            self.assertIn(name, notices)
        legal = self.read("Sources/Features/Legal/LegalView.swift")
        self.assertIn("Read full third-party software notices", legal)
        self.assertIn("subdirectory: \"Licenses\"", legal)


if __name__ == "__main__":
    unittest.main()
