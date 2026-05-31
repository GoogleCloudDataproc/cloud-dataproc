import unittest
from unittest import mock
import os
from googleapiclient.errors import HttpError

# Mock google.auth before importing checks
with mock.patch('google.auth.default', return_value=(mock.MagicMock(), None)):
    from modules.storage.checks import check_bucket_iam_policy, run_checks

class TestStorageChecks(unittest.TestCase):

    def setUp(self):
        self.mock_storage_service = mock.MagicMock()
        self.project_id = "test-project"
        self.sa_email = "test-sa@test-project.iam.gserviceaccount.com"
        self.bucket_name = "test-bucket"

    def test_check_bucket_iam_policy_sufficient(self):
        self.mock_storage_service.buckets().getIamPolicy().execute.return_value = {
            "bindings": [
                {"role": "roles/storage.objectUser", "members": [f"serviceAccount:{self.sa_email}"]},
            ]
        }
        results = check_bucket_iam_policy(self.mock_storage_service, self.bucket_name, self.sa_email)
        self.assertTrue(results[0][0])
        self.assertIn("sufficient roles", results[0][1])

    def test_check_bucket_iam_policy_insufficient(self):
        self.mock_storage_service.buckets().getIamPolicy().execute.return_value = {
            "bindings": [
                {"role": "roles/storage.objectViewer", "members": [f"serviceAccount:{self.sa_email}"]},
            ]
        }
        results = check_bucket_iam_policy(self.mock_storage_service, self.bucket_name, self.sa_email)
        self.assertFalse(results[0][0])
        self.assertIn("may lack required object permissions", results[0][1])

    def test_check_bucket_iam_policy_not_found(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 404
        self.mock_storage_service.buckets().getIamPolicy().execute.side_effect = HttpError(mock_resp, b"not found")
        results = check_bucket_iam_policy(self.mock_storage_service, self.bucket_name, self.sa_email)
        self.assertFalse(results[0][0])
        self.assertIn("not found", results[0][1])

    def test_check_bucket_iam_policy_permission_denied(self):
        mock_resp = mock.MagicMock()
        mock_resp.status = 403
        self.mock_storage_service.buckets().getIamPolicy().execute.side_effect = HttpError(mock_resp, b"forbidden")
        results = check_bucket_iam_policy(self.mock_storage_service, self.bucket_name, self.sa_email)
        self.assertFalse(results[0][0])
        self.assertIn("Permission denied to check IAM policy", results[0][1])

    @mock.patch.dict(os.environ, {"DATAPROC_GCS_BUCKETS": "bucket1, bucket2"})
    @mock.patch('modules.storage.checks.check_bucket_iam_policy')
    def test_run_checks_with_buckets(self, mock_check_bucket):
        mock_check_bucket.return_value = [(True, "Bucket Check Pass")]
        results = run_checks(self.mock_storage_service, self.project_id, "us-central1", self.sa_email)
        self.assertEqual(mock_check_bucket.call_count, 2)
        mock_check_bucket.assert_any_call(self.mock_storage_service, "bucket1", self.sa_email)
        mock_check_bucket.assert_any_call(self.mock_storage_service, "bucket2", self.sa_email)
        # INFO message + 2 * results from mock_check_bucket
        self.assertEqual(len(results), 3)

    def test_run_checks_no_env_var(self):
        results = run_checks(self.mock_storage_service, self.project_id, "us-central1", self.sa_email)
        self.assertEqual(len(results), 1)
        self.assertIsNone(results[0][0])
        self.assertIn("DATAPROC_GCS_BUCKETS environment variable not set", results[0][1])

    @mock.patch.dict(os.environ, {"DATAPROC_GCS_BUCKETS": "  "})
    def test_run_checks_empty_env_var(self):
        results = run_checks(self.mock_storage_service, self.project_id, "us-central1", self.sa_email)
        self.assertEqual(len(results), 1)
        self.assertIsNone(results[0][0])
        self.assertIn("DATAPROC_GCS_BUCKETS is set but contains no bucket names", results[0][1])

    def test_run_checks_no_sa_email(self):
        results = run_checks(self.mock_storage_service, self.project_id, "us-central1", None)
        self.assertEqual(len(results), 1)
        self.assertFalse(results[0][0])
        self.assertIn("VM Service Account email not provided", results[0][1])

if __name__ == '__main__':
    unittest.main()
