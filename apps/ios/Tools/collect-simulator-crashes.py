#!/usr/bin/env python3
"""Retain complete, recent KANTA crash reports, including delayed IPS writes.

Called only after a failed simulator capture. Logs are not a substitute for a
crashed-thread report. Preserve unparseable reports for manual diagnosis too.
"""
import argparse
import hashlib
import json
from pathlib import Path
import time


def report_roots(home, udid):
    return [
        home / 'Library/Logs/DiagnosticReports',
        home / 'Library/Developer/CoreSimulator/Devices' / udid
        / 'data/Library/Logs/CrashReporter',
    ]


def parse_ips(text):
    # Apple IPS may contain a metadata JSON object followed by the payload.
    decoder = json.JSONDecoder()
    remaining = text.lstrip()
    while remaining:
        value, end = decoder.raw_decode(remaining)
        if isinstance(value, dict) and 'threads' in value:
            return value
        remaining = remaining[end:].lstrip()
    raise ValueError('No IPS thread payload')


def summary(text):
    payload = parse_ips(text)
    threads = payload.get('threads', [])
    index = payload.get('faultingThread')
    selected = [t for t in threads if t.get('triggered')]
    if not selected and isinstance(index, int) and 0 <= index < len(threads):
        selected = [threads[index]]
    # Preserve image UUID/base/offset data for exact-build symbolication.
    return json.dumps({key: payload.get(key) for key in (
        'procName', 'pid', 'exception', 'termination', 'vmRegionInfo',
        'faultingThread', 'usedImages'
    )} | {'crashedThreads': selected}, indent=2)


def collect(roots, output, since, wait_seconds=30):
    output.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + wait_seconds
    copied = {}
    while True:
        for root in roots:
            if not root.exists():
                continue
            for path in root.rglob('*'):
                if (path.suffix.lower() not in {'.ips', '.crash'}
                        or not path.name.lower().startswith(('kanta-', 'gelokaraoke-'))):
                    continue
                try:
                    if path.stat().st_mtime < since:
                        continue
                    data = path.read_bytes()
                    # Different report roots may use the same basename.
                    prefix = hashlib.sha256(str(path).encode()).hexdigest()[:12]
                    destination = output / (prefix + '-' + path.name)
                    destination.write_bytes(data)
                    copied[str(path)] = str(destination)
                    if path.suffix.lower() == '.ips':
                        try:
                            rendered = summary(data.decode('utf-8'))
                        except (ValueError, UnicodeError, TypeError, KeyError) as error:
                            rendered = f'IPS not yet parseable: {error}; raw report retained.'
                        destination.with_suffix('.summary.txt').write_text(rendered)
                except OSError as error:
                    print(f'Cannot retain {path}: {error}')
        # Wait the bounded window even after discovery: ReportCrash may still
        # be writing the payload or generating another report for this launch.
        if time.monotonic() >= deadline:
            break
        time.sleep(min(1, max(0, deadline - time.monotonic())))
    manifest = {'since_epoch': since, 'reports': copied,
                'status': 'reports-retained' if copied else 'no-crash-report-found'}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest, indent=2))
    return copied


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('udid')
    parser.add_argument('output', type=Path)
    parser.add_argument('--since', type=float, required=True)
    args = parser.parse_args()
    collect(report_roots(Path.home(), args.udid), args.output, args.since)
