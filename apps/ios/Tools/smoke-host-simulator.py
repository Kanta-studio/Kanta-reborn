#!/usr/bin/env python3
"""Run real iOS Simulator Host/CONTROL startup on the Core CI-built app.

No second build/workflow is required. A SpringBoard screenshot is not a pass:
the app must still be alive when simctl terminate is issued for each role.
On crash, retain bounded simulator logs, complete IPS reports and matching
executable/dSYMs for a later symbolicated diagnosis. Not a hardware audio test.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

BUNDLE_ID = "com.gelo.karaoke"
OUT = Path("ci-host-smoke")


def choose_iphone(payload: dict) -> tuple[str, str, str]:
    options = []
    for runtime, devices in payload.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for device in devices:
            name = device.get("name", "")
            udid = device.get("udid")
            if name.startswith("iPhone") and udid and device.get("isAvailable", True):
                options.append((name, udid, device.get("state", "Shutdown")))
    for preferred in ("iPhone 18 Pro Max", "iPhone 17 Pro Max",
                      "iPhone 16 Pro Max", "iPhone 15 Pro Max"):
        for option in options:
            if option[0] == preferred:
                return option
    if options:
        return options[0]
    raise RuntimeError("No available iOS iPhone simulator for Host runtime acceptance")


def command(*args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    print("+", " ".join(args), flush=True)
    return subprocess.run(args, env=env, check=True, text=True)


def app_bundle() -> Path:
    products = Path("build/DerivedData/Build/Products/Release-iphonesimulator")
    apps = sorted(products.glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError(f"Expected one Release simulator app, found {len(apps)}")
    return apps[0]


def collect_failure(udid: str | None, since: float, app: Path | None) -> None:
    evidence = OUT / "diagnostics"
    evidence.mkdir(parents=True, exist_ok=True)
    if udid:
        for args in (
            ("Tools/capture-simulator-diagnostics.py", udid, str(evidence / "simulator.log")),
            ("Tools/collect-simulator-crashes.py", udid, str(evidence / "crashes"),
             "--since", str(since)),
        ):
            try:
                command(sys.executable, *args)
            except (OSError, subprocess.CalledProcessError) as exc:
                print(f"Crash evidence collection issue: {exc}", file=sys.stderr)
    if app and app.exists():
        symbols = evidence / "symbols"
        symbols.mkdir(exist_ok=True)
        shutil.copytree(app, symbols / app.name, dirs_exist_ok=True)
        for dsym in app.parent.glob("*.dSYM"):
            shutil.copytree(dsym, symbols / dsym.name, dirs_exist_ok=True)


def main() -> int:
    OUT.mkdir(exist_ok=True)
    since = time.time()
    udid = None
    app = None
    started_boot = False
    try:
        app = app_bundle()
        devices = json.loads(subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "--json"], text=True
        ))
        name, udid, state = choose_iphone(devices)
        print(f"Runtime smoke device: {name} ({udid}), current state: {state}")
        if state != "Booted":
            command("xcrun", "simctl", "boot", udid)
            started_boot = True
        command("xcrun", "simctl", "bootstatus", udid, "-b")
        command("xcrun", "simctl", "install", udid, str(app))

        for role, controls in (("host", "0"), ("control", "1")):
            env = dict(os.environ)
            env.update({
                "SIMCTL_CHILD_GELO_SCREENSHOT_MODE": "host",
                "SIMCTL_CHILD_KANTA_DEMO_MODE": "1",
                "SIMCTL_CHILD_KANTA_CONTROL_EXPANDED": controls,
                "SIMCTL_CHILD_KANTA_FULLSCREEN": "0",
            })
            command("xcrun", "simctl", "launch", udid, BUNDLE_ID, env=env)
            time.sleep(3)
            command("xcrun", "simctl", "io", udid, "screenshot", str(OUT / f"{role}.png"))
            # A screenshot by itself can be SpringBoard after a SIGSEGV.
            # Termination must succeed, proving the app is still alive.
            command("xcrun", "simctl", "terminate", udid, BUNDLE_ID)
            print(f"PASS: {role} remained alive through capture")

        # Fresh real catalog, not demo fixtures. Restart the same container to
        # verify durable removal before offline restoration. No second build.
        for phase in ("initial", "restart"):
            env = dict(os.environ)
            env.update({"SIMCTL_CHILD_GELO_SCREENSHOT_MODE": "library",
                        "SIMCTL_CHILD_KANTA_DEMO_MODE": "0",
                        "SIMCTL_CHILD_KANTA_STARTER_SMOKE": phase})
            container = Path(subprocess.check_output(
                ["xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"], text=True).strip())
            result_path = container / "Documents" / f"starter-smoke-{phase}.json"
            result_path.unlink(missing_ok=True)
            command("xcrun", "simctl", "launch", udid, BUNDLE_ID, env=env)
            deadline = time.monotonic() + 45
            while not result_path.exists() and time.monotonic() < deadline:
                time.sleep(0.25)
            if not result_path.exists():
                raise RuntimeError(f"No starter {phase} runtime evidence")
            result = json.loads(result_path.read_text())
            shutil.copy2(result_path, OUT / result_path.name)
            if result.get("passed") is not True:
                raise RuntimeError(f"Starter {phase}: {result}")
            command("xcrun", "simctl", "io", udid, "screenshot", str(OUT / f"starter-{phase}.png"))
            command("xcrun", "simctl", "terminate", udid, BUNDLE_ID)
            print(f"PASS: real starter {phase}: {result}", flush=True)

        (OUT / "capture.json").write_text(json.dumps({
            "source_sha": os.getenv("GITHUB_SHA", "unknown"),
            "device": name,
            "udid": udid,
            "screens": ["host.png", "control.png"],
            "result": "Host/CONTROL alive; real starter playback, lyrics, queue, remove/restart/restore passed; not physical device acceptance",
        }, indent=2) + "\n")
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"::error::KANTA Host/CONTROL simulator smoke failed: {exc}", file=sys.stderr)
        collect_failure(udid, since, app)
        return 1
    finally:
        if started_boot and udid:
            subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False)


if __name__ == "__main__":
    sys.exit(main())

