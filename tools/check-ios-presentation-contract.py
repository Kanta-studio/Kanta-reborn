#!/usr/bin/env python3
"""Check iOS presentation ownership and regression coverage without a simulator."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'apps/ios/Sources'
TEST = ROOT / 'apps/ios/Tests/KantaUITests/KantaVisualWalkthroughUITests.swift'


def verify():
    root = (APP / 'App/RootView.swift').read_text()
    host = (APP / 'Features/Host/HostView.swift').read_text()
    stage = (APP / 'Features/Host/KantaMainPlayerView.swift').read_text()
    test = TEST.read_text()
    checks = {
        'root owns navigation sheet identity': '.sheet(item: $activeNavigation' in root and 'onDismiss:' in root,
        'root rejects overlapping menu presentations': (
            'guard activeNavigation == nil && !navigationDismissing else { return }' in root
            and 'guard presentationGate.acquire(.navigation) else { return }' in root),
        'host receives navigation presentation state': 'navigationSheetPresented: activeNavigation != nil' in root and 'navigationSheetPresented' in host,
        'single authoritative navigation state': 'navigationPresentation' not in root and 'navigationTransition' not in root,
        'host uses one sheet coordinator': '.sheet(item: $activeHostSheet' in host and 'showingHostControls' not in host,
        'stage uses one sheet coordinator': '.sheet(item: $activeStageSheet' in stage and 'showingSearch' not in stage and 'showingQueue' not in stage,
        'playback does not mutate root navigation': 'snapshot.transport' not in root,
        'real playback walkthrough': 'func testStarterPlaybackAndControls()' in test,
        'library dismissal then search coverage': 'Search did not present the keypad after library dismissal' in test,
        'stage search accessibility identifier': 'stage.search' in stage,
    }
    for name, passed in checks.items():
        print(('PASS' if passed else 'FAIL') + ': ' + name)
    if not all(checks.values()):
        raise SystemExit(1)


if __name__ == '__main__':
    verify()
