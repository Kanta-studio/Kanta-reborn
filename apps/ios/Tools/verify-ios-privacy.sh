#!/usr/bin/env bash
set -euo pipefail

# plistlib validates the same plist data on Linux and hosted macOS.
python3 - <<'PY'
import plistlib
from pathlib import Path

with open('Config/GeloKaraoke-Info.plist', 'rb') as stream:
    info = plistlib.load(stream)
with open('Config/PrivacyInfo.xcprivacy', 'rb') as stream:
    privacy = plistlib.load(stream)

def require(condition, message):
    if not condition:
        raise SystemExit('::error::' + message)

require(bool(info.get('NSCameraUsageDescription')), 'Missing live camera usage description.')
require(bool(info.get('NSMicrophoneUsageDescription')), 'Missing microphone usage description.')
require(bool(info.get('NSSpeechRecognitionUsageDescription')), 'Missing voice-search speech usage description.')
require(bool(info.get('NSLocalNetworkUsageDescription')), 'Missing local-network usage description.')
require('_gelokaraoke._tcp' in info.get('NSBonjourServices', []), 'Missing Bonjour service.')
require(privacy.get('NSPrivacyTracking') is False, 'Tracking must remain disabled.')
require('Config/PrivacyInfo.xcprivacy' in Path('project.yml').read_text(), 'Privacy manifest is not bundled.')
reasons = {entry['NSPrivacyAccessedAPIType']: set(entry['NSPrivacyAccessedAPITypeReasons'])
           for entry in privacy.get('NSPrivacyAccessedAPITypes', [])}
for category, expected in {
    'NSPrivacyAccessedAPICategoryUserDefaults': {'CA92.1'},
    'NSPrivacyAccessedAPICategoryFileTimestamp': {'C617.1', '3B52.1'},
    'NSPrivacyAccessedAPICategorySystemBootTime': {'35F9.1'},
}.items():
    require(expected <= reasons.get(category, set()), 'Missing required reason for ' + category)
print('Privacy configuration guard passed.')
PY
