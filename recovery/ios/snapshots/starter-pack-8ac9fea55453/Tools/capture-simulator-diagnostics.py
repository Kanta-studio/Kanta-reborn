#!/usr/bin/env python3
"""Bounded macOS/iOS Simulator log capture on a failed screenshot launch.

Unlike GNU `timeout`, Python's subprocess timeout is installed on GitHub's
macOS runners. Capture app, SpringBoard and RunningBoard process exits without
letting `log show` consume the entire workflow timeout.
"""
import argparse
import pathlib
import subprocess
import sys


def run(udid: str, output: pathlib.Path) -> None:
    cmd = [
        "xcrun", "simctl", "spawn", udid,
        "log", "show", "--last", "3m", "--style", "compact",
        "--predicate",
        '(process == "KANTA") OR (process == "ReportCrash") OR '
        '(eventMessage CONTAINS[c] "com.gelo.karaoke")',
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        print("command:", " ".join(cmd), file=handle)
        try:
            result = subprocess.run(
                cmd, stdout=handle, stderr=subprocess.STDOUT,
                timeout=18, check=False,
            )
            print(f"log show exit={result.returncode}", file=handle)
        except subprocess.TimeoutExpired:
            print("log show exceeded 18 seconds and was killed", file=handle)
        except OSError as error:
            print(f"Cannot run log show: {error}", file=handle)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("udid")
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    run(args.udid, args.output)
