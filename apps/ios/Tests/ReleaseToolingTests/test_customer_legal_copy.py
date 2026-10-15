"""Customer-facing legal and privacy parity guard for web and iOS."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "PublicSite"
APP = ROOT / "Sources/Features/Legal/LegalView.swift"


class CustomerLegalCopyTests(unittest.TestCase):
    def test_navigation_has_legal_and_privacy(self):
        for filename in ("index.html", "features.html", "support.html",
                         "songbook.html", "privacy.html", "legal.html"):
            with self.subTest(page=filename):
                html = (WEB / filename).read_text(encoding="utf-8")
                self.assertIn('href="/legal"', html)
                self.assertIn('href="/privacy"', html)
                self.assertIn('href="/support"', html)
                self.assertIn('href="#content"', html)

    def test_customer_disclosures_preserved(self):
        legal = (WEB / "legal.html").read_text()
        privacy = (WEB / "privacy.html").read_text()
        for term in ("public performance", "copyright", "third-party", "Songbook"):
            self.assertIn(term.lower(), legal.lower())
        for term in ("not encrypted", "Apple", "Vercel", "temporary",
                     "Filipino/Taglish", "no advertising", "code does not"):
            self.assertIn(term.lower(), privacy.lower())
        self.assertIn("does not delete your original", privacy.lower())

    def test_app_and_site_are_linked(self):
        swift = APP.read_text()
        for location in ("/privacy", "/legal", "/support"):
            self.assertIn("https://kanta-public.vercel.app" + location, swift)
        self.assertIn("not encrypted", swift.lower())
        self.assertIn("public performance", swift.lower())
        self.assertIn("apple", swift.lower())
        self.assertIn("songbook", swift.lower())

    def test_page_has_no_tracker_or_external_scripts(self):
        for filename in ("privacy.html", "legal.html"):
            html = (WEB / filename).read_text()
            self.assertNotIn("<script", html.lower())
            self.assertNotIn("google-analytics", html.lower())
            self.assertNotIn("cookie-banner", html.lower())


if __name__ == "__main__":
    unittest.main()
