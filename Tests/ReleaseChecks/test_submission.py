import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('submission', Path(__file__).resolve().parents[2] / 'Tools/validate_submission.py')
submission = importlib.util.module_from_spec(spec)
spec.loader.exec_module(submission)


class SubmissionChecks(unittest.TestCase):
    def test_rejects_local_placeholder_and_credential_urls(self):
        for url in ['http://privacy.invalid', 'https://example.org/privacy', 'https://127.0.0.1/privacy', 'https://192.168.1.2', 'https://[::1]', 'https://localhost', 'https://host.local', 'https://user:secret@developer.apple.com', 'https://developer.apple.com/#fragment']:
            self.assertFalse(submission.public_https(url), url)

    def test_accepts_public_https(self):
        self.assertTrue(submission.public_https('https://developer.apple.com/support/'))

    def test_catches_missing_publisher_and_manifest(self):
        errors = submission.validate({}, {}, {})
        self.assertTrue(any('Herausgeber' in error for error in errors))
        self.assertTrue(any('privacyURL' in error for error in errors))
        self.assertTrue(any('CA92.1' in error for error in errors))

    def test_valid_configuration_is_accepted_without_network(self):
        errors = submission.validate(
            dict(publisher='Fixture publisher', contactEmail='support@developer.apple.com', privacyURL='https://developer.apple.com/privacy/', supportURL='https://developer.apple.com/support/'),
            dict(NSPrivacyTracking=False, NSPrivacyTrackingDomains=[], NSPrivacyCollectedDataTypes=[], NSPrivacyAccessedAPITypes=[dict(NSPrivacyAccessedAPIType='NSPrivacyAccessedAPICategoryUserDefaults', NSPrivacyAccessedAPITypeReasons=['CA92.1'])]),
            dict(ITSAppUsesNonExemptEncryption=False, NSLocalNetworkUsageDescription='Fixture network purpose'))
        self.assertEqual(errors, [])


if __name__ == '__main__':
    unittest.main()
