#!/usr/bin/env python3
"""Preserve recent package-process crash evidence from the hosted macOS runner."""

import importlib.util
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ios = root / "apps/ios"
stamp = ios / "swift-tests-start.txt"
if stamp.exists():
    since = int(stamp.read_text().strip())
    output = ios / "swift-test-crashes"
    output.mkdir(exist_ok=True)
    spec = importlib.util.spec_from_file_location(
        "crash_reports", ios / "Tools/collect-simulator-crashes.py"
    )
    reports = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reports)
    count = 0
    for source in sorted((Path.home() / "Library/Logs/DiagnosticReports").glob("*GeloKaraoke*.ips")):
        if source.stat().st_mtime < since:
            continue
        shutil.copy2(source, output / source.name)
        try:
            (output / (source.stem + ".summary.json")).write_text(reports.summary(source.read_text()))
        except (ValueError, KeyError):
            pass
        count += 1
    print(f"Retained {count} recent package crash reports.")
else:
    print("Package tests did not start; no crash reports collected.")
