#!/usr/bin/env python3
"""Repackage accepted CI outputs without rebuilding or changing application bytes."""
from __future__ import annotations
import hashlib
import io
import json
import os
from pathlib import Path
import plistlib
import urllib.request
import zipfile

REPO = "usermalik20-del/Kanta-reborn"
BUILDS = {
    "android": {"run": 38885716463, "artifact": 12039807731, "source": "d777334eec73996116fdf2c01d97ac73a3a53958"},
    "ios": {"run": 38806377805, "artifact": 12007058242, "source": "3c12a1fb962ac956250a8f238c01eace13f560d2"},
}
LIMIT = 128 * 1024 * 1024

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        redirected = super().redirect_request(request, fp, code, message, headers, newurl)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected

def api(path: str, *, binary=False):
    request = urllib.request.Request("https://api.github.com/repos/" + REPO + "/" + path,
        headers={"Authorization": "Bearer " + os.environ["GITHUB_TOKEN"],
                 "Accept": "application/vnd.github+json", "User-Agent": "KANTA-verified-downloads"})
    with urllib.request.build_opener(SafeRedirect()).open(request, timeout=90) as response:
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("Artifact response exceeded bound")
    return data if binary else json.loads(data)

def accepted(run, artifact, expected):
    if run.get("conclusion") != "success" or run.get("head_sha") != expected["source"]:
        raise ValueError("Source run is not the accepted successful revision")
    if run.get("id") != expected["run"] or artifact.get("id") != expected["artifact"]:
        raise ValueError("Artifact identity mismatch")
    if artifact.get("expired") or artifact.get("workflow_run", {}).get("id") != expected["run"]:
        raise ValueError("Artifact expired or belongs to another run")

def one(archive, suffix):
    choices = [entry for entry in archive.infolist() if (entry.filename == suffix.lstrip("/") or entry.filename.endswith(suffix)) and not entry.is_dir()]
    if len(choices) != 1 or choices[0].file_size > LIMIT:
        raise ValueError("Missing, ambiguous or oversized artifact member: " + suffix)
    return archive.read(choices[0])

def validate_ipa(data, info, checksum):
    if hashlib.sha256(data).hexdigest() != checksum.split()[0].lower():
        raise ValueError("IPA checksum differs from accepted build")
    if (str(info.get("run_id")) != str(BUILDS["ios"]["run"]) or info.get("platform") != "iPhoneOS"
            or info.get("signed") is not False or info.get("personal_signing") is not True
            or info.get("icloud_available") is not False):
        raise ValueError("Unexpected IPA configuration")
    with zipfile.ZipFile(io.BytesIO(data)) as app:
        if app.testzip() is not None:
            raise ValueError("Corrupt IPA")
        names = app.namelist()
        if any(name.endswith("embedded.mobileprovision") for name in names):
            raise ValueError("Unexpected provisioning material")
        plist = plistlib.loads(app.read("Payload/KANTA.app/Info.plist"))
        if plist.get("CFBundleIdentifier") != "com.gelo.karaoke" or "iPhoneOS" not in plist.get("CFBundleSupportedPlatforms", []):
            raise ValueError("Unexpected device app")
        if not any(name.endswith("THIRD_PARTY_AUDIO_NOTICES.txt") for name in names):
            raise ValueError("Required software notices missing")

def main():
    output = Path("verified-downloads")
    manifest = {"repository": REPO, "packaging_run": os.environ.get("GITHUB_RUN_ID"), "builds": {}}
    for platform, expected in BUILDS.items():
        run = api("actions/runs/" + str(expected["run"]))
        metadata = api("actions/artifacts/" + str(expected["artifact"]))
        accepted(run, metadata, expected)
        data = api("actions/artifacts/" + str(expected["artifact"]) + "/zip", binary=True)
        digest = metadata.get("digest", "")
        if digest.startswith("sha256:") and digest[7:] != hashlib.sha256(data).hexdigest():
            raise ValueError("Downloaded artifact digest mismatch")
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if sum(entry.file_size for entry in archive.infolist()) > LIMIT or archive.testzip() is not None:
                raise ValueError("Corrupt or oversized artifact archive")
            if platform == "android":
                application = one(archive, "/app-debug.apk")
                with zipfile.ZipFile(io.BytesIO(application)) as apk:
                    if "AndroidManifest.xml" not in apk.namelist() or "classes.dex" not in apk.namelist():
                        raise ValueError("Not an Android application")
                name = "KANTA-Android-preview-" + expected["source"][:8] + ".apk"
                note = "Android testing preview. The APK is byte-identical to the accepted build. The automated test APK is not included.\n"
            else:
                application = one(archive, "/KANTA-personal-unsigned.ipa")
                info = json.loads(one(archive, "/artifact-info.json"))
                validate_ipa(application, info, one(archive, "/KANTA-personal-unsigned.sha256").decode())
                name = "KANTA-iOS-personal-unsigned-" + expected["source"][:8] + ".ipa"
                note = "Unsigned iPhoneOS personal-signing input. Separate trusted personal signing is required before installation. iCloud Save is unavailable in this build.\n"
        destination = output / platform
        destination.mkdir(parents=True, exist_ok=True)
        (destination / name).write_bytes(application)
        checksum = hashlib.sha256(application).hexdigest()
        (destination / "SHA256.txt").write_text(checksum + "  " + name + "\n")
        (destination / "README.txt").write_text(note + "Source: " + expected["source"] + "\nValidated run: " + str(expected["run"]) + "\n")
        details = dict(expected, file=name, sha256=checksum, bytes=len(application), signed=False if platform == "ios" else "debug")
        (destination / "build-info.json").write_text(json.dumps(details, indent=2) + "\n")
        manifest["builds"][platform] = details
        print(platform + ": verified original application bytes, " + str(len(application)) + " bytes", flush=True)
    (output / "downloads.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

