"""Source and selection checks for the one-run Core CI Host smoke."""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Tools/smoke-host-simulator.py"


def load_script():
    spec = importlib.util.spec_from_file_location("smoke_host_simulator", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class HostSmokeWorkflowTests(unittest.TestCase):
    def test_select_prefers_pro_max_without_requiring_exact_model(self):
        code = load_script()
        payload = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
            {"name": "iPhone 15", "udid": "regular", "isAvailable": True},
            {"name": "iPhone 17 Pro Max", "udid": "preferred", "isAvailable": True},
            {"name": "iPhone 18 Pro Max", "udid": "unavailable", "isAvailable": False},
        ]}}
        self.assertEqual(code.choose_iphone(payload)[1], "preferred")

    def test_no_iphone_fails_closed(self):
        code = load_script()
        with self.assertRaisesRegex(RuntimeError, "No available iOS iPhone"):
            code.choose_iphone({"devices": {"iOS": [
                {"name": "iPad Pro", "udid": "ipad", "isAvailable": True}
            ]}})

    def test_launch_requires_live_process_and_retains_crash_evidence(self):
        script = SCRIPT.read_text()
        self.assertIn('for role, controls in (("host", "0"), ("control", "1")):', script)
        self.assertIn('"SIMCTL_CHILD_KANTA_CONTROL_EXPANDED": controls', script)
        self.assertIn('command("xcrun", "simctl", "terminate", udid, BUNDLE_ID)', script)
        self.assertIn('collect_failure(udid, since, app)', script)
        self.assertIn('shutil.copytree(app, symbols / app.name', script)

    def test_core_ci_build_and_runtime_smoke_share_one_job(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("-derivedDataPath build/DerivedData", workflow)
        self.assertIn("python3 Tools/smoke-host-simulator.py", workflow)
        self.assertLess(workflow.index("swift test"),
                        workflow.index("python3 Tools/smoke-host-simulator.py"))
        self.assertLess(workflow.index("Build Release iOS Simulator app"),
                        workflow.index("Launch Host and CONTROL in the same CI run"))
        self.assertIn("Retain simulator runtime proof and crash evidence", workflow)
        self.assertIn("if: always()", workflow)


if __name__ == "__main__":
    unittest.main()
