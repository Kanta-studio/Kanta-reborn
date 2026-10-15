#!/usr/bin/env python3
"""Check deployed-site routes, local anchors and download provenance."""
import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "apps/web"

class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.errors = []
    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append("Duplicate ID: " + attrs["id"])
            self.ids.add(attrs["id"])
        for attribute in ("href", "src"):
            if attribute in attrs:
                self.links.append(attrs[attribute])

def main():
    pages = {}
    for path in WEB.glob("*.html"):
        page = Page()
        source = path.read_text()
        page.feed(source)
        assert not page.errors, (path.name, page.errors)
        assert '<html lang="en"' in source and 'name="viewport"' in source, path.name
        assert "<title>" in source and 'id="content"' in source, path.name
        assert "github.com/kanta-ph/" not in source, path.name
        pages[path.name] = page
    assert len(pages) == 10, "A public page is missing"
    for name, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                assert url.scheme in ("https", "mailto"), (name, link)
                continue
            destination = url.path.lstrip("/") if url.path else name
            if not destination:
                destination = "index.html"
            elif not Path(destination).suffix:
                destination += ".html"
            assert (WEB / destination).is_file(), (name, link)
            if url.fragment:
                assert destination in pages and url.fragment in pages[destination].ids, (name, link)
    original = ROOT / "docs/evidence/website/2026-10-15"
    for name in ("songbook.js", "songbook.css"):
        assert (WEB / name).read_bytes() == (original / name).read_bytes(), name + " reader changed"
    config = json.loads((WEB / "vercel.json").read_text())
    headers = {h["key"]: h["value"] for h in config["headers"][0]["headers"]}
    assert "connect-src 'none'" in headers["Content-Security-Policy"]
    assert "script-src 'self'" in headers["Content-Security-Policy"]
    manifest = json.loads((WEB / "downloads.json").read_text())
    assert manifest["repository"] == "kanta-gelo/Kanta-reborn"
    assert manifest["signInRequired"] is True and manifest["retentionDays"] == 30
    for platform, filename in (("android", "android.html"), ("ios", "ios-download.html")):
        build = manifest[platform]
        expected = "/actions/runs/" + str(manifest["packagingRun"]) + "/artifacts/" + str(build["artifact"])
        assert expected in (WEB / filename).read_text(), filename + " artifact differs from manifest"
    assert manifest["ios"]["signed"] is False and manifest["ios"]["personalSigningRequired"]
    assert not manifest["ios"]["icloudAvailable"]
    print("10 pages: routes, anchors, source notices, private reader and verified download provenance passed")

if __name__ == "__main__":
    main()
