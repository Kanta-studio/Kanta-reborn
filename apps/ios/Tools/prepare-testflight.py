"""Generate deterministic build identity and internal-only export settings."""
import os
from pathlib import Path
import plistlib
import sys


def build_number(run_number, run_attempt):
    run, attempt = int(run_number), int(run_attempt)
    if not 1 <= run <= 9999 or not 1 <= attempt <= 99:
        raise ValueError('Workflow build identity exceeds supported Apple version components')
    return f'{run}.{attempt}'


def export_options(team_id):
    return {
        'method': 'app-store-connect',
        'teamID': team_id,
        'signingStyle': 'automatic',
        'stripSwiftSymbols': True,
        'uploadSymbols': True,
        'manageAppVersionAndBuildNumber': False,
        'testFlightInternalTestingOnly': True,
    }


if __name__ == '__main__':
    if sys.argv[1:] == ['--export-options']:
        path = Path(os.environ['RUNNER_TEMP']) / 'ExportOptions.plist'
        path.write_bytes(plistlib.dumps(export_options(os.environ['APPLE_TEAM_ID'])))
    elif not sys.argv[1:]:
        number = build_number(os.environ['GITHUB_RUN_NUMBER'], os.environ['GITHUB_RUN_ATTEMPT'])
        with open(os.environ['GITHUB_ENV'], 'a') as output:
            output.write(f'KANTA_BUILD_NUMBER={number}\n')
    else:
        raise SystemExit('Unknown arguments')
