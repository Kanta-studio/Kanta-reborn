#!/usr/bin/env python3
"""Package an UNSIGNED iphoneos app for subsequent personal signing by AltServer.

This utility does not request Apple credentials, provision devices, install an
app, sign binaries, or modify an Xcode build. Never use a Simulator .app.
"""
from __future__ import annotations

import argparse
import plistlib
import sys
import zipfile
from pathlib import Path

EXPECTED_BUNDLE_ID = "com.gelo.karaoke"


class PackagingError(ValueError):
    pass


def validate_app(app: Path) -> None:
    if not app.is_dir() or app.suffix != ".app":
        raise PackagingError("Expected an existing iPhoneOS .app directory.")
    info_path = app / "Info.plist"
    if not info_path.is_file():
        raise PackagingError("Missing Info.plist in app bundle.")
    try:
        with info_path.open("rb") as handle:
            info = plistlib.load(handle)
    except (ValueError, OSError, TypeError, plistlib.InvalidFileException) as error:
        raise PackagingError("App Info.plist is unreadable.") from error

    if info.get("CFBundleIdentifier") != EXPECTED_BUNDLE_ID:
        raise PackagingError("Unexpected KANTA bundle identifier.")
    if info.get("CFBundlePackageType") != "APPL":
        raise PackagingError("Input is not an iOS application bundle.")
    if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []):
        raise PackagingError(
            "This is not an iPhoneOS device build; simulator builds cannot be installed."
        )
    executable = info.get("CFBundleExecutable")
    if (
        not isinstance(executable, str)
        or executable in ("", ".", "..")
        or "/" in executable
        or chr(92) in executable
        or not (app / executable).is_file()
    ):
        raise PackagingError("Missing or unsafe app executable.")
    if (app / "embedded.mobileprovision").exists():
        raise PackagingError("Use the unsigned device build, not a provisioned IPA.")
    if any(child.is_symlink() for child in app.rglob("*")):
        raise PackagingError("Unexpected symlink; fail closed rather than flatten it.")
    if not list(app.rglob("PrivacyInfo.xcprivacy")):
        raise PackagingError("Missing Apple app privacy manifest.")
    if not list(app.rglob("THIRD_PARTY_AUDIO_NOTICES.txt")):
        raise PackagingError("Missing legally required DSP copyright/license notices.")


def package_unsigned_ipa(app: Path, output: Path) -> None:
    validate_app(app)
    if output.suffix.lower() != ".ipa":
        raise PackagingError("Output must end in .ipa.")
    if output.resolve().is_relative_to(app.resolve()):
        raise PackagingError("Output cannot be written inside the app bundle.")

    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(output.name + ".tmp")
    staging.unlink(missing_ok=True)
    try:
        with zipfile.ZipFile(
            staging, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=6
        ) as archive:
            for source in sorted(app.rglob("*")):
                if not source.is_file():
                    continue
                entry = Path("Payload") / app.name / source.relative_to(app)
                archive.write(source, arcname=entry.as_posix())
        with zipfile.ZipFile(staging) as check:
            if check.testzip() is not None:
                raise PackagingError("Corrupted IPA file detected.")
            if not any(name.startswith("Payload/") for name in check.namelist()):
                raise PackagingError("IPA Payload is empty.")
        staging.replace(output)
    finally:
        staging.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True, help="Unsigned iphoneos .app")
    parser.add_argument("--output", type=Path, required=True, help="KANTA .ipa output")
    args = parser.parse_args()
    try:
        package_unsigned_ipa(args.app, args.output)
    except (PackagingError, OSError, zipfile.BadZipFile) as error:
        print("KANTA AltStore packaging blocked: " + str(error), file=sys.stderr)
        return 1
    print(f"Prepared unsigned iPhoneOS IPA: {args.output.name}")
    print("Next: sign/install locally with AltServer and YOUR Apple account.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
