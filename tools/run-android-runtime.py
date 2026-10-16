#!/usr/bin/env python3
"""Run clean-install Android acceptance with bounded startup and retained diagnostics."""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]

def run(*args, **kwargs):
    print("+", " ".join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), check=True, **kwargs)

def export_capture(adb: Path, name: str) -> None:
    destination = ROOT / ("android-" + name)
    with destination.open("wb") as output:
        run(adb, "exec-out", "run-as", "ph.kanta.reborn", "cat",
            "files/" + name, stdout=output, timeout=20)
    if destination.stat().st_size < 1024:
        raise RuntimeError("Missing valid Android screenshot: " + name)


def instrument(adb: Path, mode: str, video: bool) -> None:
    recording = None
    video_path = "/sdcard/kanta-walkthrough.mp4"
    try:
        if video:
            recording = subprocess.Popen(
                [str(adb), "shell", "screenrecord", "--time-limit", "120", video_path],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(2)
        logfile = ROOT / ("android-runtime.log" if mode == "full" else "android-visual.log")
        with logfile.open("wb") as output:
            run(adb, "shell", "am", "instrument", "-w", "-e", "kanta.mode", mode,
                "ph.kanta.reborn.test/ph.kanta.reborn.RuntimeChecks",
                stdout=output, stderr=subprocess.STDOUT, timeout=240 if mode == "full" else 90)
        result = logfile.read_text(errors="replace")
        print(result, flush=True)
        if "KANTA runtime:" not in result or "checks passed" not in result:
            raise RuntimeError(mode + " runtime instrumentation did not pass")
    finally:
        if recording is not None:
            pids = subprocess.run([str(adb), "shell", "pidof", "screenrecord"],
                                  capture_output=True, text=True, timeout=10)
            if pids.returncode == 0:
                for pid in pids.stdout.split():
                    if pid.isdecimal():
                        subprocess.run([str(adb), "shell", "kill", "-2", pid],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                       timeout=10, check=False)
            try:
                recording.wait(timeout=15)
            except subprocess.TimeoutExpired:
                recording.terminate()
                recording.wait(timeout=10)
            run(adb, "pull", video_path, ROOT / "android-visual-walkthrough.mp4", timeout=35)
            if (ROOT / "android-visual-walkthrough.mp4").stat().st_size < 1024:
                raise RuntimeError("Missing Android walkthrough video")
            subprocess.run([str(adb), "shell", "rm", video_path], timeout=15, check=False)

    files = (["runtime-stage.png", "runtime-camera.png"] if mode == "full" else
             ["runtime-ui-control.png", "runtime-ui-my-set.png",
              "runtime-ui-scenic.png", "runtime-ui-realm.png",
              "runtime-ui-loop.png"])
    for filename in files:
        export_capture(adb, filename)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("focused", "full", "release"), default="full")
    parser.add_argument("--video", action="store_true",
                        help="Record a short UI tour in release mode")
    args = parser.parse_args()
    if args.video and args.mode != "release":
        parser.error("--video is supported only for release visual acceptance")
    sdk = Path(os.environ["ANDROID_HOME"])
    adb = sdk / "platform-tools/adb"
    env = dict(os.environ)
    env["ANDROID_AVD_HOME"] = tempfile.mkdtemp(prefix="kanta-avd-")
    env["QT_QPA_PLATFORM"] = "offscreen"
    emulator = None
    try:
        run(sdk / "cmdline-tools/latest/bin/sdkmanager", "platform-tools", "emulator",
            "system-images;android-35;google_apis;x86_64", timeout=300)
        run(sdk / "cmdline-tools/latest/bin/avdmanager", "create", "avd", "--force", "-n", "kanta-test",
            "-k", "system-images;android-35;google_apis;x86_64", "--device", "pixel_6",
            env=env, input="no\n", text=True, timeout=60)
        run("sudo", "chmod", "666", "/dev/kvm", timeout=10)
        with (ROOT / "emulator.log").open("wb") as log:
            emulator = subprocess.Popen([str(sdk / "emulator/emulator"), "-avd", "kanta-test", "-no-window",
                "-no-audio", "-no-snapshot", "-no-boot-anim", "-gpu", "swiftshader", "-accel", "on",
                "-cores", "2", "-memory", "2048", "-camera-front", "emulated"], env=env, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 420
            booted = False
            while time.monotonic() < deadline:
                if emulator.poll() is not None: raise RuntimeError(f"Emulator exited before boot ({emulator.returncode})")
                try:
                    state = subprocess.run([str(adb), "shell", "getprop", "sys.boot_completed"],
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=8)
                    if state.returncode == 0 and state.stdout.strip() == "1": booted = True; break
                except subprocess.TimeoutExpired: pass
                time.sleep(2)
            if not booted: raise RuntimeError("Emulator did not boot within seven minutes")
            run(adb, "shell", "input", "keyevent", "82", timeout=15)
            run(adb, "install", ROOT / "apps/android/app/build/outputs/apk/debug/app-debug.apk", timeout=60)
            run(adb, "install", ROOT / "apps/android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk", timeout=60)
            if args.mode == "release":
                # The brief recorded UI tour precedes the exhaustive unrecorded runtime suite.
                instrument(adb, "focused", args.video)
                instrument(adb, "full", False)
            else:
                instrument(adb, args.mode, False)
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Android runtime acceptance failed: {error}", flush=True)
        for name in ("emulator.log", "android-runtime.log"):
            path = ROOT / name
            if path.exists(): print(name + ":\n" + "\n".join(path.read_text(errors="replace").splitlines()[-50:]), flush=True)
        return 1
    finally:
        if adb.exists():
            try:
                with (ROOT / "android-logcat.log").open("wb") as output:
                    subprocess.run([str(adb), "logcat", "-d"], stdout=output, stderr=subprocess.STDOUT, timeout=20)
            except (OSError, subprocess.TimeoutExpired): pass
        if emulator is not None and emulator.poll() is None:
            emulator.terminate()
            try: emulator.wait(timeout=15)
            except subprocess.TimeoutExpired: emulator.kill(); emulator.wait()

if __name__ == "__main__": raise SystemExit(main())
