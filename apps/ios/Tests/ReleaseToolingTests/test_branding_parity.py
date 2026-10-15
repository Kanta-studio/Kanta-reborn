"""Verify KANTA's installed icon and onscreen artwork never diverge."""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
ICON = ROOT / "Sources/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
MARK = ROOT / "Sources/App/Assets.xcassets/KantaBrandArtwork.imageset/KantaBrandArtwork.png"
VISUAL_STYLE = ROOT / "Sources/App/GeloVisualStyle.swift"
BRAND_VIEW = ROOT / "Sources/App/KantaBrandView.swift"


class BrandingParityTests(unittest.TestCase):
    def test_native_brand_matches_installed_icon_bytes(self):
        self.assertEqual(ICON.read_bytes(), MARK.read_bytes())

    def test_app_icon_is_1024_square_png(self):
        data = ICON.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(data[12:16], b"IHDR")
        self.assertEqual(struct.unpack(">II", data[16:24]), (1024, 1024))

    def test_app_mark_uses_shared_asset_not_procedural_placeholder(self):
        source = BRAND_VIEW.read_text(encoding="utf-8")
        self.assertIn('Image("KantaBrandArtwork")', source)
        self.assertNotIn('Image(systemName: "mic.fill")', source)

    def test_palette_is_not_system_pink_or_grouped_gray(self):
        source = VISUAL_STYLE.read_text(encoding="utf-8")
        self.assertNotIn("Color.pink", source)
        self.assertNotIn(".systemGroupedBackground", source)
        self.assertIn("static let cyan", source)
        self.assertIn("static let gold", source)


if __name__ == "__main__":
    unittest.main()
