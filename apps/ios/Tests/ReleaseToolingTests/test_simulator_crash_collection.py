import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('crashes', ROOT / 'Tools/collect-simulator-crashes.py')
crashes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crashes)

PAYLOAD = {'exception': {'signal': 'SIGSEGV'}, 'faultingThread': 1,
           'threads': [{'frames': []}, {'frames': [{'symbol': 'HostView.body'}]}],
           'usedImages': [{'uuid': 'matching-build', 'base': 4096}]}


class CrashCollectionTests(unittest.TestCase):
    def test_two_object_ips_keeps_faulting_thread_and_image_identity(self):
        result = json.loads(crashes.summary('{}\n' + json.dumps(PAYLOAD)))
        self.assertEqual(result['crashedThreads'], [PAYLOAD['threads'][1]])
        self.assertEqual(result['usedImages'], PAYLOAD['usedImages'])
        self.assertEqual(result['exception']['signal'], 'SIGSEGV')

    def test_triggered_thread_takes_precedence(self):
        data = dict(PAYLOAD, threads=[{'triggered': True}, {'frames': []}])
        self.assertEqual(json.loads(crashes.summary(json.dumps(data)))['crashedThreads'],
                         [{'triggered': True}])

    def test_only_recent_app_reports_and_no_basename_collisions(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            roots = [base / 'host', base / 'simulator']
            for root in roots:
                root.mkdir()
                for name in ['KANTA-new.ips', 'KANTA-old.ips', 'Other-new.ips']:
                    path = root / name
                    path.write_text(json.dumps(PAYLOAD))
                    os.utime(path, (50, 50) if 'old' in name else (200, 200))
            result = crashes.collect(roots, base / 'out', since=100, wait_seconds=0)
            self.assertEqual(len(result), 2)
            self.assertEqual(len(set(result.values())), 2)
            self.assertTrue(all(Path(p).read_text() == json.dumps(PAYLOAD) for p in result.values()))

    def test_delayed_partial_report_is_refreshed_and_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            report = base / 'KANTA-late.ips'
            report.write_text('{')
            def finish_write(_):
                report.write_text(json.dumps(PAYLOAD))
            with patch.object(crashes.time, 'monotonic', side_effect=[0, 0, 0, 2]), \
                 patch.object(crashes.time, 'sleep', side_effect=finish_write):
                result = crashes.collect([base], base / 'out', since=0, wait_seconds=1)
            self.assertEqual(len(result), 1)
            destination = Path(next(iter(result.values())))
            self.assertEqual(json.loads(destination.read_text()), PAYLOAD)
            self.assertIn('SIGSEGV', destination.with_suffix('.summary.txt').read_text())

    def test_missing_report_is_explicit_and_not_a_successful_runtime_test(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / 'out'
            crashes.collect([Path(folder) / 'absent'], out, since=100, wait_seconds=0)
            self.assertEqual(json.loads((out / 'manifest.json').read_text())['status'],
                             'no-crash-report-found')


if __name__ == '__main__':
    unittest.main()
