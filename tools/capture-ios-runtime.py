#!/usr/bin/env python3
"""Capture real iPhone/iPad interactions and preserve failed XCTest evidence."""
from __future__ import annotations
import json
import argparse
from collections import deque
import os
from pathlib import Path
import signal
import subprocess

OUT = Path("runtime-captures")
# Four full UI walkthroughs can exceed the combined XCTest per-case limit.
SUITE_TIMEOUT_SECONDS = 1080

def run(*args: str, **kwargs):
    print("+", " ".join(args), flush=True)
    return subprocess.run(args, check=True, **kwargs)

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", choices=("iphone", "ipad"))
    parser.add_argument("--mode", choices=("focused", "release"), default="release")
    parser.add_argument("--video", action="store_true", help="Record the visual run; off by default")
    args = parser.parse_args()
    requested = args.device
    OUT.mkdir(exist_ok=True)
    devices = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True))
    available = [(d["name"], d["udid"]) for runtime, rows in devices["devices"].items()
                 if "iOS" in runtime for d in rows if d.get("isAvailable", True)]
    selected = []
    for label, prefix, preferred in (("iphone", "iPhone", "iPhone 16 Pro"), ("ipad", "iPad", "iPad (9th generation)")):
        if requested and requested != label: continue
        choices = [(name, udid) for name, udid in available if name.startswith(prefix)]
        if not choices: raise RuntimeError(f"No available {label} simulator")
        name, udid = next((item for item in choices if item[0] == preferred), choices[0])
        selected.append(dict(label=label, name=name, udid=udid))
    results = []
    for device in selected:
        label, udid = device["label"], device["udid"]
        recorder = None
        passed = False
        test_log = OUT / f"{label}-tests.log"
        try:
            subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
            run("xcrun", "simctl", "bootstatus", udid, "-b", timeout=180)
            with (OUT / f"{label}-recording.log").open("w") as recording_log:
                if args.video:
                    recorder = subprocess.Popen(["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264",
                        str(OUT / f"{label}-walkthrough.mp4")], stdout=recording_log, stderr=subprocess.STDOUT)
                with test_log.open("w") as log:
                    run("xcodebuild", "test-without-building", "-project", "GeloKaraoke.xcodeproj",
                        "-scheme", "GeloKaraoke", "-configuration", "Release", "-destination",
                        f"platform=iOS Simulator,id={udid}", "-derivedDataPath", "build/DerivedData",
                        "-resultBundlePath", str(OUT / f"{label}.xcresult"), "-parallel-testing-enabled", "NO",
                        "-test-timeouts-enabled", "YES", "-default-test-execution-time-allowance", "120",
                        "-maximum-test-execution-time-allowance", "180",
                        "-only-testing:KantaUITests/KantaVisualWalkthroughUITests" +
                            ("/testFocusedVisualSmoke" if args.mode == "focused" else ""),
                        "CODE_SIGNING_ALLOWED=NO", stdout=log, stderr=subprocess.STDOUT,
                        timeout=480 if args.mode == "focused" else SUITE_TIMEOUT_SECONDS)
                passed = True
        except (OSError, subprocess.SubprocessError) as error:
            print(f"{label}: {error}", flush=True)
            if test_log.is_file():
                print(f"--- {label} XCTest log tail ---", flush=True)
                with test_log.open(errors="replace") as log:
                    for line in deque(log, maxlen=100):
                        print(line.rstrip(), flush=True)
                print(f"--- end {label} XCTest log tail ---", flush=True)
        finally:
            if recorder is not None:
                if recorder.poll() is None: recorder.send_signal(signal.SIGINT)
                try: recorder.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    recorder.kill()
                    recorder.wait()
            result = OUT / f"{label}.xcresult"
            if (result / "Info.plist").is_file():
                subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                    "--output-path", str(OUT / f"{label}-screenshots")], check=False, timeout=90)
            subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, timeout=30)
        video = OUT / f"{label}-walkthrough.mp4"
        passed = passed and (not args.video or (video.exists() and video.stat().st_size > 0))
        results.append(dict(**device, passed=passed))
        print(f"{label}: {'PASS' if passed else 'FAIL'}", flush=True)
    (OUT / (f"manifest-{requested}.json" if requested else "manifest.json")).write_text(json.dumps(dict(source_sha=os.environ.get("GITHUB_SHA"),
        results=results, mode=args.mode, recording=args.video,
        boundary="Actual simulator XCTest interactions and screenshots; video is optional. No physical audio proof."), indent=2) + "\n")
    return 0 if all(item["passed"] for item in results) else 1

if __name__ == "__main__": raise SystemExit(main())
