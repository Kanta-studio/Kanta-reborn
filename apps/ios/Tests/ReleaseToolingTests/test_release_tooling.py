import base64
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Tools' / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

signing = module('check-signing-readiness')
release = module('prepare-testflight')

class SigningReadinessTests(unittest.TestCase):
    def test_missing_credentials_report_names_only(self):
        failures = signing.validate({})
        self.assertEqual(len(failures), len(signing.REQUIRED))
        self.assertTrue(all(name in ' '.join(failures) for name in signing.REQUIRED))

    def test_bad_secret_value_never_appears_in_errors(self):
        sentinel = 'DO_NOT_PRINT_PRIVATE_MATERIAL'
        failures = signing.validate({name: sentinel for name in signing.REQUIRED})
        self.assertTrue(failures)
        self.assertNotIn(sentinel, ' '.join(failures))

    def test_valid_structure_accepts_wrapped_base64_without_keychain_secret(self):
        env = dict.fromkeys(signing.REQUIRED, 'password')
        env.update(APPLE_TEAM_ID='ABCDEFGHIJ', APP_STORE_CONNECT_KEY_ID='1234567890',
                   APP_STORE_CONNECT_ISSUER_ID='12345678-1234-1234-1234-123456789abc',
                   APP_STORE_CONNECT_API_KEY_P8_BASE64=base64.encodebytes(b'-----BEGIN PRIVATE KEY-----\ntest fixture only').decode(),
                   APPLE_DISTRIBUTION_CERT_P12_BASE64=base64.encodebytes(b'test fixture only').decode())
        self.assertEqual(signing.validate(env), [])

class ReleaseIdentityTests(unittest.TestCase):
    def test_retry_and_next_dispatch_have_distinct_builds(self):
        self.assertEqual([release.build_number(*x) for x in [(2,1),(2,2),(3,1)]], ['2.1','2.2','3.1'])

    def test_invalid_build_components_fail_closed(self):
        for pair in [(0,1),(10000,1),(1,0),(1,100)]:
            with self.assertRaises(ValueError):
                release.build_number(*pair)

    def test_export_cannot_be_promoted_to_external_distribution(self):
        options = release.export_options('ABCDEFGHIJ')
        self.assertIs(options['testFlightInternalTestingOnly'], True)
        self.assertIs(options['manageAppVersionAndBuildNumber'], False)
